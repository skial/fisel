package;

import sys.io.File;
import uhx.sys.Ioe;
import haxe.io.Input;
import haxe.io.Output;
import uhx.sys.ExitCode;

using haxe.io.Path;
using sys.FileSystem;

/**
 * ...
 * @author Skial Bainn
 */
@:cmd
@:usage(
	'fisel [options]',
	'fisel --help',
	'fisel -?'
)
class LibRunner extends Ioe implements Klas {
	
	public static function main() {
		var lib = new LibRunner( Sys.args() );
		lib.exit();
	}

	@:isVar
	@alias('i')
	public var input(default, set):String;
	
	@:isVar
	@alias('o')
	public var output(default, set):String;
	
	public function new(args:Array<String>) {
		super();
		@:cmd _;
		process();
	}
	
	override private function process(i:Input = null, o:Output = null) {
		super.process(
			input == null ? null : (File.read( input ):Input), 
			output == null ? null : (File.write( output ):Output)
		);
		
		if (content != '') {
			var fisel = new Fisel( content );
			var result = fisel.toString();
			
			stdout.writeString( result );
			
			exitCode = ExitCode.SUCCESS;
			
		} else {
			exitCode = ExitCode.ERRORS;
			
		}
	}
	
	private function set_input(v:String):String {
		return input = '${Sys.getCwd()}$v'.normalize();
	}
	
	private function set_output(v:String):String {
		return input = '${Sys.getCwd()}$v'.normalize();
	}
	
}