import haxe.macro.Expr;
import haxe.macro.Context;

using haxe.macro.Tools;

class Macros {
	static public macro function assign(typePath:Expr, eOld:Expr, eNew:Expr) {
		var type:haxe.macro.Type = Context.getType(typePath.toString());

		var expr = [];

		switch type.follow() {
			case TAnonymous(_.get() => anon):
				var fieldName;
				for (f in anon.fields) {
					fieldName = f.name;
					expr.push(macro {
						if ($eNew.$fieldName != null)
							$eOld.$fieldName = $eNew.$fieldName;
					});
				}
			case _:
		}

		return macro $a{expr};
	}
}
