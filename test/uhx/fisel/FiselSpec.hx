package uhx.fisel;

import utest.Assert;
import uhx.types.Uri;
import haxe.ds.StringMap;
import uhx.lexer.Html.NodeType;
import uhx.lexer.Html as HtmlLexer;
import utest.Runner;
import utest.ui.Report;

#if sys
import sys.io.File;
#end

using Detox;
using StringTools;
using haxe.io.Path;

#if sys
using sys.FileSystem;
#end

/**
 * ...
 * @author Skial Bainn
 */
class FiselSpec {
	
	public static function main() {
		var runner = new Runner();
		runner.addCase( new FiselSpec() );
		Report.create( runner );
		runner.run();
	}
	
	public var fisel:Fisel;
	public var assets:Uri = (Sys.getCwd() + '/assets/').normalize();

	@:access(Fisel) public function new() {
		fisel = new Fisel();
		
		fisel.document = 
		#if sys
			File.getContent( '$assets/index.html' ).parse()
		#else
			''.parse()
		#end;
		
		for (json in ['{"title":"JSON Title"}', '{"comment":"Hello JSON World"}']) {
			fisel.data.set( json, haxe.Json.parse( json ) );
			
		}
		
		fisel.location = '$assets/index.html';
		fisel.linkMap = new StringMap();
		fisel.linkMap.set( assets, fisel );
		fisel.find();
		fisel.load();
	}
	
	public function testBuild_Before() {
		var imports = fisel.document.find( 'link[rel="import"]' );
		var content = fisel.document.find( 'content[select]' );
		
		Assert.equals( 2, imports.length );
		Assert.equals( 4, content.length );
		
		trace( print( fisel.document.collection.filter( noWhitespace ) ) );
	}
	
	@:access(Fisel) public function testBuild_After() {
		fisel.build();
		
		var imports = fisel.document.find( 'link[rel="import"]' );
		var content = fisel.document.find( 'content[select]' );
		
		Assert.equals( 0, imports.length );
		Assert.equals( 0, content.length );
		
		var body = fisel.document.find( 'body' );
		
		Assert.isTrue( body.length > 0 );
		Assert.equals( 'header', body.children().getNode( 0 ).nodeName );
		Assert.equals( 1, body.children().getNode( 0 ).children().length );	// <nav>
		Assert.equals( 1, body.children().getNode( 0 ).children().getNode().children().length );	// <ul>
		Assert.equals( 3, body.children().getNode( 0 ).children().getNode().children().getNode().children().length );	// <li>
		
		Assert.equals( 'article', body.children().getNode( 1 ).nodeName );
		
		Assert.equals( 'footer', body.children().getNode( 2 ).nodeName );
		Assert.equals( 1, body.children().getNode( 2 ).children().length );	// <ul>
		Assert.equals( 3, body.children().getNode( 2 ).children().getNode().children().length );	// <li>
		
		Assert.equals( 'Header H1! | FooBar.io JSON Title', fisel.document.find( 'title' ).text() );
		
		trace( print( fisel.document.collection.filter( noWhitespace ) ) );
	}
	
	// utility methods
	
	// From Fisel's LibRunner.hx file
	private function noWhitespace(node:DOMNode):Bool {
		var result = true;
		
		if (node.nodeType == NodeType.Text && node.nodeValue.trim() == '') {
			result = false;
			
		} else if ((node.nodeType == NodeType.Element || node.nodeType == NodeType.Document) && node.hasChildNodes()) {
			node.childNodes = node.childNodes.filter( noWhitespace );
			
		}
		
		return result;
	}
	
	// From Fisel's LibRunner.hx file.
	// Completely bypass Detox's built in printer, its wrong in places.
	private function print(c:Array<DOMNode>, tab:String = ''):String {
		var ref;
		var node;
		var result = '';
		
		for (i in 0...c.length) {
			node = c[i];
			
			if (node.nodeType != NodeType.Text && i == 0) result += '\n';
			
			switch (node.nodeType) {
				case NodeType.Element, NodeType.Document, NodeType.Unknown:
					// Grab the underlying structure instead of accessing via the `DOMNode` abstract class.
					ref = switch (node.token()) {
						case Keyword(Tag(r)): r;
						case _: null;
					}
					
					if (ref != null) {
						result += '$tab<${ref.name}';
						
						if (ref.attributes.iterator().hasNext()) {
							result += ' ' + [for (k in ref.attributes.keys()) '$k="${ref.attributes.get(k)}"'].join(' ');
							
						}
						
						if (ref.selfClosing) {
							result += ' />';
							
						} else {
							result += '>';
							if (ref.tokens.length > 0) result += print(ref.tokens, '$tab\t');
							result += ((result.charAt(result.length - 1) == '\n') ? tab : '') + '</${ref.name}>';
							
						}
						
					}
					
				case NodeType.Text:
					result += node.nodeValue;
				
				case NodeType.Comment:
					result += '<!--${node.nodeValue}-->';
					
			}
			
			if (node.nodeType != NodeType.Text) result += '\n';
		}
		
		return result;
	}
	
}