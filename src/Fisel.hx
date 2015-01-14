package;

import byte.ByteData;
import haxe.ds.StringMap;
import uhx.io.Uri;
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
  * - [ ] Imported HTML replaces a `<content select="css"/>` which was selected by the `select` attribute.
  * - [ ] Any unmatched selectors then search the document in its current state for a match.
  * - [ ] Attributes on `<content id="1" data-name="Skial" /> which don't exist on the imported HTML are transfered over.
  */

class Fisel {
	
	public static function main() {
		
	}
	
	private static var _css:CssParser;
	private static var _html:HtmlParser;
	private static var _selector:SelectorParser;
	
	public var document:DOMCollection;
	
	private var uri:Uri;
	private var insertionPoints:DOMCollection;
	private var importCache:StringMap<Fisel> = new Map();
	
	public function new(html:String) {
		if (_css == null) _css = new CssParser();
		if (_html == null) _html = new HtmlParser();
		if (_selector == null) _selector = new SelectorParser();
		
		document = html.parse();
		insertionPoints = document.find( 'content[select]' );
		var imports = document.find( 'link[rel*="import"][href*=".htm"]' );
		var bases = document.find( 'base[href]' );
		
		// If no `<base />` is found, set the root uri to the current working directory.
		if (bases.length == 0) {
			uri = new Uri( #if !js Sys.getCwd().normalize() #else js.Browser.document.location.host #end );
			
		} else {
			var _base = bases.collection[0].attr( 'href' ).normalize();
			_base = !_base.isAbsolute() ? (#if !js Sys.getCwd() #else js.Browser.document.location.host #end + _base).normalize() : _base;
			uri = new Uri( _base );
			
		}
		
		load( imports );
	}
	
	public function toString():String {
		var result = '';
		
		
		
		return result;
	}
	
	public function build():Void {
		for (key in importCache.keys()) importCache.get( key ).build();
		
		var attr;
		var matches;
		for (content in insertionPoints) {
			attr = content.attr( 'select' );
			
			if (attr.startsWith('#') && importCache.exists( attr.substring(1) )) {
				content.replaceWith( importCache.get( attr = attr.substring(1) ).document.innerHTML().htmlUnescape().parse() );
				
			} else {
				trace( attr );
				matches = document.find( attr );
				trace( matches );
				if (matches.length != 0) {
					content.replaceWith( matches );
					
				}
				
			}
			
		}
		
	}
	
	public function load(imports:DOMCollection):Void {
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
				importCache.set( id, new Fisel( content ) );
				
			}
			
		}
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
	
}