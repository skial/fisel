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
	
	public var cycle:Bool;
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
	 * Determines if this `Fisel` instance is the master document.
	 */
	@:access(Fisel) public static inline function isMaster(fisel:Fisel):Bool {
		return fisel.referrers.length == 0;
	}
	
	/**
	 * Attempts to return the master document.
	 */
	@:access(Fisel) public static function getMaster(fisel:Fisel):Null<Fisel> {
		var master:Fisel = null;
		
		for (referrer in fisel.referrers) if (referrer.isMaster()) {
			master = referrer;
			break;
			
		} else {
			master = referrer.getMaster();
			if (master != null) break;
			
		}
		
		return master;
	}
	
	/**
	 * Goes through the `Fisel` instance referrers and link list
	 * for a mtach to `child`. If `true`, its a loop.
	 */
	public static function isCycle(parent:Fisel, child:String):Bool {
		var result = parent.location == child;
		
		var referMatch = parent.referrers.filter( function(r) return r.location == child );
		var linkMatch = parent.importsList.filter( function(l) return l.location == child );
		
		return referMatch.length > 0 && linkMatch.length > 0;
	}
	
	@:access(Fisel) public static function predecessors(link:Fisel):Array<Fisel> {
		var index = -1;
		var result = [];
		var slice = [];
		
		for (referrer in link.referrers) {
			// Find the index of this `link` in its parents `importsList`/
			for (i in 0...referrer.importsList.length) if (referrer.importsList[i].location == link.location) {
				// From the top of `importsList` to `i`, fecth the corrosponding `fisel` instance.
				slice = referrer.importsList.slice(0, i);
				
				for (piece in slice) {
					result.push( referrer.importsMap.get( piece.location ) );
				}
				
				// Now get the predecessors for each `piece` and join with the `result` array.
				for (piece in slice) {
					result = result.concat( piece.predecessors() );
				}
			}
		}
		
		return result;
	}
	
	/**
	 * If this HTML document is imported by one of its child HTML document.
	 */
	public var cycle:Bool;
	
	/**
	 * This HTML document.
	 */
	public var document:DOMCollection;
	
	/**
	 * A list of `<link rel="import" href="..." />`'s found in this HTML document.
	 */
	private var importsList:Array<Link> = [];
	
	/**
	 * A map of `<link rel="import" href="..." />`'s already loaded.
	 * 	+	The `key` is the url.
	 * 	+	The `value` is a `Fisel` instance.
	 */
	private var importsMap:StringMap<Fisel>;
	
	/**
	 * The HTML documents that `<link rel="import" href="..." />` this HTML document.
	 */
	private var referrers:Array<Fisel> = [];
	
	/**
	 * The url to the import.
	 */
	public var location:String;
	
	private var links:DOMCollection;
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
			importsList.push( new Link( (location.directory() + '/' + link.attr( 'href' )).normalize() ) );
		}
	}
	
	public function load():Void {
		var path = '';
		
		for (link in importsList) {
			var f = fetch( link.location );
			
			var name = f.location.withoutDirectory();
			var linkList = f.importsList.map( function(l) return l.location.withoutDirectory() );
			var lineage = f.buildLineage().map( function(l) return l.location.withoutDirectory() );
			var predecessors = [];
			
			trace( 'The document $name has an import link list which contains: $linkList' );
			trace( 'The document $name has a set of import ancestors that are: $lineage' );
			trace( 'The document $name cycle value is: ${f.cycle}' );
			trace( 'The import predecessors of $name are: $predecessors' );
		}
	}
	
	public function toString():String {
		//build();
		return document.html();
	}
	
	/*public function build():Void {
		for (key in importCache.keys()) importCache.get( key ).build();
		
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
		imports.remove();
	}
	
	// Act like HTML imports.
	/*public function load():Void {
		var content = '';
		var attr = '';
		var id = '';
		var path;
		
		for (imp in imports) {
			attr = imp.attr( 'href' );
			path = new Uri( '$uri/$attr'.normalize() );
			
			// Allow for user defined ids, but default to the file name without its extension.
			id = imp.attr( 'id' ) != '' ? imp.attr( 'id' ) : attr.withoutExtension().withoutDirectory();
			
			if (!importCache.exists( id )) {
				content = loadFile( '$path' );
				// All content should be wrapped in `<template></template>`.
				if (content.indexOf( '<template>' ) == -1) content = '<template>$content</template>';
				importCache.set( id, new Fisel( content.parse() ) );
				
			}
			
		}
		
		for (key in importCache.keys()) importCache.get( key ).load();
	}*/
	
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
	
	/*private function request(link:DOMNode, location:String):Void {
		var result = new Fisel();
		result.location = location;
		result.importsMap = importsMap;
		result.referrers.push( this );
		importsList.push( result );
	}*/
	
	private function fetch(location:String):Fisel {
		var result:Fisel;
		
		if (importsMap.exists( location )) {
			result = importsMap.get( location );
			result.referrers.push( this );
			if (!result.cycle) result.cycle = this.isCycle( location );
			
		} else {
			result = new Fisel();
			result.document = loadFile( location ).parse();
			result.location = location;
			result.referrers.push( this );
			importsMap.set( location, result );
			result.importsMap = importsMap;
			result.cycle = this.isCycle( location );
			result.find();
			result.load();
			
		}
		
		trace( result.location.withoutDirectory() + ' ancestors are > ' + result.buildLineage().map( function(f) return f.location.withoutDirectory() ) );
		trace( location.withoutDirectory() + '::' + result.cycle + '::' + result.referrers.length );
		
		return result;
	}
	
	private static function buildLineage(fisel:Fisel):Array<Fisel> {
		var result = [];
		
		for (r in fisel.referrers) {
			result.push( r );
			if (!r.cycle) result = result.concat( r.buildLineage() );
		}
		
		return result;
	}
	
}