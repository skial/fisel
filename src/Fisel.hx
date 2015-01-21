package;

import uhx.io.Uri;
import uhx.mo.Token;
import byte.ByteData;
import uhx.select.Html;
import haxe.ds.StringMap;
import uhx.lexer.CssLexer;
import uhx.lexer.CssParser;
import uhx.lexer.HtmlLexer;
import uhx.lexer.HtmlParser;
import uhx.lexer.SelectorParser;

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

class Fisel {
	
	public static function main() {
		
	}
	
	private static var _ignore:Array<String> = ['select', 'data-text', 'data-json', 'text', 'json', 'data-dom', 'dom'];
	private static var _targets:Array<String> = [Target.TEXT, Target.JSON, Target.DOM];
	private static var _actions:Array<String> = [Action.COPY, Action.MOVE];
	private static var _css:CssParser;
	private static var _html:HtmlParser;
	private static var _selector:SelectorParser;
	
	public var document:DOMCollection;
	
	private var uri:Uri;
	private var imports:DOMCollection;
	private var insertionPoints:DOMCollection;
	private var importCache:StringMap<Fisel> = new StringMap();
	
	public function new(html:DOMCollection, ?path:String) {
		if (_css == null) _css = new CssParser();
		if (_html == null) _html = new HtmlParser();
		if (_selector == null) _selector = new SelectorParser();
		
		document = html;
		insertionPoints = document.find( 'content[select]' );
		imports = document.find( 'link[rel*="import"][href*=".htm"]' );
		var bases = document.find( 'base[href]' );
		
		if (path == null) {
			// If no `<base />` is found, set the root uri to the current working directory.
			if (bases.length == 0) {
				uri = new Uri( #if !js Sys.getCwd().normalize() #else js.Browser.document.location.host #end );
				
			} else {
				var _base = bases.collection[0].attr( 'href' ).normalize();
				_base = !_base.isAbsolute() ? (#if !js Sys.getCwd() #else js.Browser.document.location.host #end + _base).normalize() : _base;
				uri = new Uri( _base );
				
			}
			
		} else {
			uri = new Uri( path );
			
		}
		
	}
	
	public function toString():String {
		build();
		return document.html();
	}
	
	public function build():Void {
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
	public function load():Void {
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
	}
	
	#if !js
	public inline function loadFile(path:String):String {
		path = path.normalize();
		if (path.exists()) {
			return path.getContent();
		} else {
			throw 'Can not find file $path';
		}
	}
	#else
	public inline function loadFile(path:String):String {
		return '';
	}
	#end
	
	// Untested methods based on w3c html imports spec >see http://w3c.github.io/webcomponents/spec/imports/
	
	// http://w3c.github.io/webcomponents/spec/imports/#updateing-branch
	//private function updatingBranch(document:Fisel):Void {
		// Need a way to determine if `document` is the master document.
		// A master document is the html document which kicked off the chain of
		// imports.
		/*
		 * var list = document.linkList;
		 * for (link in list) {
		 * 		var location = link.location;
		 * 		var import = link.location;
		 * 		// Implement step 3 of #updateing-branch
		 * 		if (link.branch && import != null) {
		 * 			updateMarking( import );
		 * 		}
		 * }
		 */
	//}
	
	// http://w3c.github.io/webcomponents/spec/imports/#requesting-import
	/*private function requestingImport(link:DOMNode, location:String):Void {
		if (link.attr('async') == 'true') {
			// mark as async
		}
		var document = ''; // Needs to be a Fisel instance.
		var list = ''; // Needs to fisel.linkList;
		var item = { link:'', location:'' };
		// list.push( item );
		// updateMarking( masterDocument );
	}
	
	// http://w3c.github.io/webcomponents/spec/imports/#fetching-import
	private function fetchingImport(link:DOMNode, location:String):Fisel {
		
	}
	
	// http://w3c.github.io/webcomponents/spec/imports/#import-link-tree
	private function importLinkTree(parent:DOMCollection, current:DOMCollection, pool:Array<DOMCollection>) {
		// return a tree of documents
	}*/
	
}

// Untested code based on w3c html imports spec.

/*class Requested {
	public var branch:Bool;
	public var link:DOMNode;
	public var location:String;
	
	public function new(link:DOMNode, location:String, ?branch:Bool = false) {
		this.link = link;
		this.location = location;
		this.branch = branch;
	}
}*/