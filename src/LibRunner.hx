package;

import haxe.ds.StringMap;
import uhx.mo.Token;
import uhx.lexer.Html as HtmlLexer;
import uhx.lexer.Html.NodeType;
import uhx.parser.Html as HtmlParser;
import sys.io.File;
import uhx.sys.Ioe;
import haxe.io.Input;
import haxe.io.Output;
import uhx.sys.ExitCode;
import dtx.mo.DOMNode;

using Detox;
using StringTools;
using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
@:cmd
@:usage(
	'fisel --help',
	'fisel --input index.html -o /bin/index.html',
	'fisel --pretty -i index.html ## Prints to stdout',
	'fisel -o /bin/index.html ## Will wait for input on stdin'
)
class LibRunner extends Ioe {
	
	public static function main() {
		var lib = new LibRunner( Sys.args() );
		lib.exit();
	}

	/**
	 * The file to process.
	 */
	@:isVar
	@alias('i')
	public var input(default, set):String;
	
	/**
	 * The file to save to.
	 */
	@:isVar
	@alias('o')
	public var output(default, set):String;
	
	/**
	 * Pretty print HTML output.
	 */
	@alias('p')
	public var pretty:Bool = false;
	
	/**
	 * An array of json files.
	 */
	@alias('d')
	public var data:Array<String> = [];
	
	public function new(args:Array<String>) {
		super();
		@:cmd _;
		process();
	}
	
	@:access(Fisel) override private function process(i:Input = null, o:Output = null) {
		super.process(
			input == null ? null : (File.read( input ):Input), 
			output == null ? null : (File.write( output ):Output)
		);
		
		if (content != '') {
			var fisel = new Fisel();
			
			for (json in data) if ((json = json.normalize()).exists() && !json.isDirectory()) {
				fisel.data.set( json, haxe.Json.parse( File.getContent( json ) ) );
				
			}
			
			fisel.document =  content.parse();
			fisel.location = input == null ? Sys.getCwd() : input;
			fisel.linkMap = new StringMap();
			fisel.linkMap.set( fisel.location, fisel );
			fisel.find();
			fisel.load();
			fisel.build();
			
			fisel.document = fisel.document.filter( noWhitespace );
			stdout.writeString( pretty ? print( fisel.document.collection ).trim() : fisel.toString() );
			
			exitCode = ExitCode.SUCCESS;
			
		} else {
			exitCode = ExitCode.ERRORS;
			
		}
	}
	
	private function noWhitespace(node:DOMNode):Bool {
		var result = true;
		
		if (node.nodeType == NodeType.Text && node.nodeValue.trim() == '') {
			result = false;
			
		} else if ((node.nodeType == NodeType.Element || node.nodeType == NodeType.Document) && node.hasChildNodes()) {
			node.childNodes = node.childNodes.filter( noWhitespace );
			
		}
		
		return result;
	}
	
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
					result += '<!${node.nodeValue}>';
					
			}
			
			if (node.nodeType != NodeType.Text) result += '\n';
		}
		
		return result;
	}
	
	private function set_input(v:String):String {
		return input = '${Sys.getCwd()}$v'.normalize();
	}
	
	private function set_output(v:String):String {
		return input = '${Sys.getCwd()}$v'.normalize();
	}
	
}