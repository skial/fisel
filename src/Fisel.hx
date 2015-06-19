package;

import uhx.io.Uri;
import uhx.mo.Token;
import byte.ByteData;
import uhx.select.Html;
import uhx.select.Json;
import haxe.ds.StringMap;
import uhx.lexer.SelectorParser;
import uhx.lexer.CssLexer.CssSelectors;

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

@:forward @:enum abstract DataType(String) from String to String {
	//public var CSV = 'csv';
	//public var MARKDOWN = 'markdown';
	public var XML = 'xml';
	public var JSON = 'json';
	public var HTML = 'html';		// default
	public var TEXT = 'plain';
}

@:forward @:enum abstract DataAction(String) from String to String {
	public var COPY = 'copy';	// default
	public var REMOVE = 'remove';
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
	
	private static var _ignore:Array<String> = ['select', 'data-type'];
	private static var _targets:Array<String> = [DataType.TEXT, DataType.JSON, DataType.HTML];
	private static var _actions:Array<String> = [DataAction.COPY, DataAction.REMOVE];
	
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
	
	public var data:StringMap<Dynamic> = new StringMap();
	
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
		var content = '';
		
		for (link in links) {
			if (linkMap.exists( link.location )) {
				linkMap.get( link.location ).referrers.push( this );
				
			} else {
				fisel = new Fisel();
				fisel.linkMap = linkMap;
				fisel.location = link.location;
				
				// Wrap file content in a single element.
				content = loadFile( link.location );
				fisel.document = ('<fisel>' + content + '</fisel>').parse();
				// Replace `<template>` elements with its content early, else where is too late.
				var templates = fisel.document.find( 'template' );
				templates.replaceWith( templates.text().parse() );
				
				linkMap.set( link.location, fisel );
				fisel.referrers.push( this );
				fisel.find();
				fisel.load();
				
			}
			
		}
	}
	
	private static function debugPrettyPrint(tokens:Array<DOMNode>, tabs:String = ''):String {
		var results = '';
		
		for (token in tokens) {
			results += '\n$tabs';
			switch (token) {
				case Keyword(Tag( { name:n, attributes:a, tokens:t } )):
					results += '<$n>::' + [for (k in a.keys()) '$k=${a.get(k)}'].join(', ');
					if (t.length > 0) {
						tabs += '  ';
						results += '\n$tabs' + debugPrettyPrint( t, tabs );
						tabs = tabs.substring(0, tabs.length - 2);
					}
					
				case Keyword(Text( { tokens:t } )):
					results += 'text::' + t.replace('\n', '\\n').replace('\t', '\\t').replace('\r', '\\r');
					
				case _:
					
			}
			
		}
		
		return results;
	}
	
	public function toString():String {
		return document.html();
	}
	
	/**
	 * Flatten all imports into a single HTML file.
	 */
	public function build():Void {
		var fisel:Fisel = null;
		var head:DOMCollection;
		var body:DOMCollection;
		var parentHead = this.document.find( 'head' );
		var parentBody = this.document.find( 'body' );
		var insertionPoints = this.document.find( 'content[select]' );
		
		buildDependencies();
		handleInsertions();
		
		for (link in links) if (!link.cycle) {
			fisel = linkMap.get( link.location );
			
			head = fisel.document.find( 'head' );
			body = fisel.document.find( 'body' );
			
			if (parentHead.length > 0 && head.length > 0 && head.length > 0 && head.getNode().hasChildNodes()) {
				var _import = parentHead.find( 'link[rel="import"][href*="${link.location.withoutDirectory()}"]' );
				// Ignore `<base />` and `<title>` tags as your only meant to have one.
				var _content = head.getNode().find( ':not(head, base, title)' );
				
				if (_import != null && _import.length > 0 && _content != null && _content.length > 0) {
					_import.replaceWith( _content.clone() );
					
				}
				
			}
			
			if (parentBody.length > 0 && body.length > 0 && body.length > 0 && body.getNode().hasChildNodes()) {
				parentBody = parentBody.append( body.children( false ).clone() );
				
			}
			
			// Is it just a HTML fragment without a `<head>` and `<body>`?
			if (parentHead.length > 0 && parentBody.length > 0 && head.length == 0 && body.length == 0) {
				parentHead = parentHead.append( fisel.document.find( 'style, link:not([rel="import"]), meta, script[async], script[defer]' ).clone() );
				parentBody = parentBody.append( fisel.document.find( ':not(style, link:not([rel="import"]), meta, script[async], script[defer])' ).clone() );
				
			}
			
		}
		
		// Remove any remaining `<link rel="import" href="..." />` elements.
		document.find( 'link[rel="import"]' ).remove();
	}
	
	private function buildDependencies():Void {
		var fisel:Fisel = null;
		
		for (link in links) if (!link.cycle) {
			fisel = linkMap.get( link.location );
			
			// Call `build` on child imports so their imports are flattened before inclusion.
			fisel.build();
		}
	}
	
	/**
	 * This method only deals with selectors that match with
	 * an imports href value. ie `href="path/to/some/File.html"` 
	 * will match with `select="#File"`.
	 */
	private function handleInsertions():Void {
		var id:String = '';
		var fisel:Fisel = null;
		var selector:CssSelectors;
		var insertionPoints:DOMCollection = null;
		var parser:SelectorParser = new SelectorParser();
		var matched:Array<Link> = [];
		var dataType:MediaType;
		var dataAction:DataAction;
		var nodes:DOMCollection;
		
		for (link in links) if (!link.cycle) {
			fisel = linkMap.get( link.location );
			insertionPoints = document.find( 'content[select]' );
			
			for (point in insertionPoints) {
				nodes = new DOMCollection();
				selector = parser.toTokens( ByteData.ofString( point.attr( 'select' ) ), 'fisel-insert' );
				
				dataType = point.attr( 'data-type' ) != '' ? point.attr( 'data-type' ).toLowerCase() : 'text/html';
				dataAction = point.attr( 'data-action' ) != '' ? point.attr( 'data-action' ).toLowerCase() : DataAction.COPY;
				
				if (dataType.isText) switch (dataType.subtype) {
					case DataType.TEXT:
						var text = fisel.document.find( point.attr( 'select' ) );
						if (text.length > 0) {
							point.replaceWith( text.text().parse() );
							matched.push( link );
							nodes.addCollection( text );
							
						}
						
					case DataType.JSON:
						var info = [];
						for (key in data.keys()) {
							info = info.concat( Json.find( data.get( key ), point.attr( 'select' ) ) );
							
						}
						
						if (info.length > 0) {
							point.replaceWith( info.join('').parse() );
							matched.push( link );
							
						}
						
					case _:
						// Implies DataType.HTML or DataType.XML
						if (isID( selector )) {
							id = getID( selector );
							
							if (link.location.withoutDirectory().indexOf( id ) > -1) {
								point.replaceWith( fisel.document.children().clone() );
								matched.push( link );
								
							}
							
						}
					
				}
				
				if (dataAction == DataAction.REMOVE) nodes.remove();
				
			}
			
		}
		
		// Remove any matched links so they do get processed in the
		// next step.
		for (match in matched) links.remove( match );
	}
	
	private function isCombinator(selector:CssSelectors):Bool {
		var result = false;
		
		switch (selector) {
			case Combinator(_, _, _): result = true;
			case _:
		}
		
		return result;
	}
	
	private function isID(selector:CssSelectors):Bool {
		var result = false;
		
		switch (selector) {
			case ID(_): result = true;
			case Combinator(a, _, _): result = isID(a);
			case _:
		}
		
		return result;
	}
	
	private function getID(selector:CssSelectors):Null<String> {
		var result = null;
		
		switch (selector) {
			case ID(v): result = v;
			case Combinator(a, _, _): result = getID(a);
			case _:
		}
		
		return result;
	}
	
	/*public function build():Void {
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
		
		/*for (link in links) {
			if (!link.cycle) linkMap.get( link.location ).build();
			
		}
	}*/
	
	#if !js
	public inline function loadFile(path:String):Null<String> {
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