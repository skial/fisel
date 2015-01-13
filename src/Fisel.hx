package;

import byte.ByteData;
import uhx.lexer.CssLexer;
import uhx.lexer.CssParser;
import uhx.lexer.HtmlLexer;
import uhx.lexer.HtmlParser;
import uhx.lexer.SelectorParser;

using Detox;

/**
 * ...
 * @author Skial Bainn
 * Haitian Creole for string
 */

class Fisel {
	
	public static function main() {
		
	}
	
	private static var _css:CssParser;
	private static var _html:HtmlParser;
	private static var _selector:SelectorParser;
	
	public function new(html:String) {
		if (_css == null) _css = new CssParser();
		if (_html == null) _html = new HtmlParser();
		if (_selector == null) _selector = new SelectorParser();
		
		var elements = html.parse();
		var contents = elements.find( 'content[selector]' );
	}
	
}