package;

import uhx.io.Uri;
import uhx.mo.Token;
import byte.ByteData;
import uhx.select.Html;
import haxe.ds.StringMap;

using Fisel;
using Detox;
using StringTools;
using haxe.io.Path;

#if !js
using sys.io.File;
using sys.FileSystem;
#end

/**
 * ...
 * @author Skial Bainn
 * Haitian Creole for string
 * @see http://www.w3.org/TR/html-imports/
 */

 /**
  * - [x] Allow root uri to be set via `<base href="path/to/directory" />`.
  * - [x] Root uri can be relative.
  * - [x] Root uri can be absolute.
  * - [x] Allow resources to be loaded from the filesystem.
  * - [ ] Allow resources to be loaded from the web.
  * - [x] Make sure all resource uris end with `html` or `htm`.
  * - [x] Each loaded resource is a Fisel instance.
	* - [x] Allow HTML not wrapped in `<template></template>`.
	* - [x] Automatically wrap any HTML not wrapped in `<template></template>`.
  * - [x] Imported HTML replaces a `<content select="css"/>` which was selected by the `select` attribute.
  * - [x] Any unmatched selectors then search the document in its current state for a match.
  * - [x] Attributes on `<content id="1" data-name="Skial" /> which don't exist on the imported HTML are transfered over.
  * - [x] Transfered attributes which match by name will have the value added only if it doesnt exist, space separated to the end.
  * - [x] Detect if attributes value is space or dashed separated and use the correct character when appending new values. Default is space.
  * - [x] Remove `<link rel="import" />` when `Fisel::build` has been run.
  */

@:forward @:enum abstract Target(String) from String to String {
	public var TEXT = 'text';
	public var JSON = 'json';
	public var DOM = 'dom';		// default
}

@:forward @:enum abstract Action(String) from String to String {
	public var MOVE = 'move';
	public var COPY = 'copy';	// default
}

private class Link {
	
	/**
	 * If this HTML document is imported by one of its child HTML document.
	 */
	public var cycle:Bool;
	
	/**
	 * The url to the import.
	 */
	public var location:String;
	
	public inline function new(location:String, cycle:Bool = false) {
		this.location = location;
		this.cycle = cycle;
	}
	
}

class Fisel {
	
	public static function main() {
		
	}
	
	private static var _ignore:Array<String> = ['select', 'data-text', 'data-json', 'text', 'json', 'data-dom', 'dom'];
	private static var _targets:Array<String> = [Target.TEXT, Target.JSON, Target.DOM];
	private static var _actions:Array<String> = [Action.COPY, Action.MOVE];
	
	/**
	 * Goes through the `parent`'s referrers link list
	 * for a mtach to `child`. If `true`, its a loop.
	 */
	public static function isCycle(child:Link, parent:Fisel):Bool {
		var result = false;
		
		for (r in parent.referrers) if (r.location == child.location) {
			result = true;
			break;
		}
		
		return result;
	}
	
	/**
	 * This HTML document.
	 */
	public var document:DOMCollection;
	
	/**
	 * A list of `<link rel="import" href="..." />`'s found in this HTML document.
	 */
	private var links:Array<Link> = [];
	
	/**
	 * A map of `<link rel="import" href="..." />`'s already loaded.
	 * 	+	The `key` is the url.
	 * 	+	The `value` is a `Fisel` instance.
	 */
	private var linkMap:StringMap<Fisel>;
	
	/**
	 * The HTML documents that `<link rel="import" href="..." />` this HTML document.
	 */
	private var referrers:Array<Fisel> = [];
	
	/**
	 * The url to the import.
	 */
	public var location:String;
	
	private var imports:DOMCollection;
	private var insertionPoints:DOMCollection;
	private var importCache:StringMap<Fisel> = new StringMap();
	
	public function new() {
		/*var bases = document.find( 'base[href]' );
		
		if (path == null) {
			// If no `<base />` is found, set the root uri to the current working directory.
			if (bases.length == 0) {
				location = #if !js Sys.getCwd().normalize() #else js.Browser.document.location.host #end;
				
			} else {
				var _base = bases.collection[0].attr( 'href' ).normalize();
				_base = !_base.isAbsolute() ? (#if !js Sys.getCwd() #else js.Browser.document.location.host #end + _base).normalize() : _base;
				location = _base;
				
			}
			
		} else {
			location = path;
			
		}*/
	}
	
	public function find():Void {
		for (link in document.find( 'link[rel*="import"][href*=".htm"]' )) {
			var l =  new Link( (location.directory() + '/' + link.attr( 'href' )).normalize() );
			links.push( l );
			l.cycle = Fisel.isCycle(l, this);
		}
	}
	
	public function load():Void {
		var path = '';
		var fisel:Fisel;
		
		for (link in links) {
			
			if (linkMap.exists( link.location )) {
				linkMap.get( link.location ).referrers.push( this );
				
			} else {
				fisel = new Fisel();
				fisel.linkMap = linkMap;
				fisel.location = link.location;
				fisel.document = loadFile( link.location ).parse();
				linkMap.set( link.location, fisel );
				fisel.referrers.push( this );
				fisel.find();
				fisel.load();
				
			}
			
		}
	}
	
	public function toString():String {
		//build();
		return document.html();
	}
	
	public function build():Void {
		/*for (key in importCache.keys()) importCache.get( key ).build();
		
		var attr;
		var matches;
		var targets;
		for (content in insertionPoints) {
			attr = content.attr( 'select' );
			
			if (attr.startsWith('#') && importCache.exists( attr.substring(1) )) {
				content.replaceWith( 
					importCache.get( attr = attr.substring(1) ).document.find( 'template:first-child' ).innerHTML().htmlUnescape().parse() 
				);
				
			} else {
				matches = document.find( attr );
				
				if (matches.length != 0) {
					var attributes = [for (a in content.attributes) a].filter( 
						function(a) {
							a.name = a.name.startsWith('data-') ? a.name.substring(5) : a.name;
							return _targets.indexOf(a.name) > -1 || _actions.indexOf(a.value) > -1;
						}
					);
					
					switch (attributes[0]) {
						case { name:Target.TEXT, value:Action.MOVE }:
							content.replaceWith( matches.text().parse() );
							matches.remove();
							
						case { name:Target.TEXT, value:Action.COPY } | { name:Target.TEXT }:
							content.replaceWith( matches.text().parse() );
							
						case { name:Target.JSON } :
							
							
						case { name:Target.DOM, value:Action.MOVE } :
							targets = matches;
							content.replaceWith( targets );
							
						case { name:Target.DOM, value:Action.COPY } | { name:Target.DOM } | null | _:
							targets = matches.clone();
							content.replaceWith( targets );
							
					}
					
					attributes = [for (a in content.attributes) a].filter(
						function(a) return _ignore.indexOf( a.name ) == -1
					);
					
					var value;
					var separator;
					if (targets != null) {
						for (target in targets) for (a in attributes) if ((value = target.attr( a.name )) == '') {
							target.setAttr(a.name, a.value);
							
						} else if (value.indexOf( a.value ) == -1) {
							separator = !value.startsWith('-') && value.indexOf('-') > -1? '-' : ' ';
							target.setAttr( a.name, '$value$separator${a.value}' );
							
						}
						
						targets = null;
						
					}
				}
				
			}
			
		}
		
		// Remove any unresolved `<content select="..." />`
		document.find( 'content[select]' ).remove();
		
		// Remove all `<link rel="import" />`
		imports.remove();*/
		
		for (link in links) {
			trace( link.location.withoutDirectory() );
			//trace( link.location.withoutDirectory() + ' cycle status is ' + link.cycle + ' for document ' + location.withoutDirectory() );
			trace( 'ancestors==' + linkMap.get( link.location ).lineage().map( function(s) return s.location.withoutDirectory() ) );
			trace( 'predescessors==' + linkMap.get( link.location ).predecessors().map( function(s) return s.location.withoutDirectory() ) );
			if (!link.cycle) linkMap.get( link.location ).build();
			
		}
	}
	
	#if !js
	public inline function loadFile(path:String):String {
		path = path.normalize();
		if (path.exists()) {
			return path.getContent();
		}
		return '';
	}
	#else
	public inline function loadFile(path:String):String {
		return '';
	}
	#end
	
	/**
	 * Returns an array of `Fisel` instances which preceede
	 * `link` in the import chain.
	 */
	public static function lineage(link:Fisel):Array<Fisel> {
		var results = link.referrers.filter( function(r) return link.links.filter(function(l) return !l.cycle && l.location == r.location).length == 0 );
		var refs = results.copy();
		
		while (refs.length > 0) {
			var current = refs.pop();
			var length = current.referrers.length - 1;
			
			while (length > -1) {
				var referrer = current.referrers[length];
				
				if (results.lastIndexOf( referrer ) == -1 && referrer.location != link.location) {
					refs.unshift( referrer );
					results.unshift( referrer );
					
				}
				
				length--;
			}
			
		}
		
		return results;
	}
	
	public static function predecessors(link:Fisel):Array<Fisel> {
		var index = -1;
		var results = [];
		var ancestor:Fisel = null;
		var referrer:Fisel = null;
		var ancestors = link.lineage();
		
		while (ancestors.length > 0) {
			ancestor = ancestors.pop();
			
			for (i in 0...ancestor.links.length) if (!ancestor.links[i].cycle && ancestor.links[i].location == link.location) {
				index = i;
				break;
			}
			
			if (index > 0) for (piece in ancestor.links.slice(0, index)) if(!piece.cycle) {
				referrer = link.linkMap.get( piece.location );
				if (results.lastIndexOf( referrer ) == -1) results.unshift( referrer );
				
			}
			
		}
		
		return results;
	}
	
}