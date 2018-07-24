package ;

#if (macro||eval)
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;

using tink.MacroApi;
#end
using tink.CoreApi;

@:forwardStatics abstract Remote<T#if !(macro||eval):WorkerProxy.WorkerLike#end>(T) from T {

    public inline function new(v) this = v;

    @:to public inline function unwrap():T return this;

    @:op(a.b) public static macro function resolve<T>(self:Expr, name:String):ExprOf<Promise<T>> {
        var type = (macro $self.unwrap()).typeof().sure();
        var ctype = type.toComplex();
        var proxy = macro:WorkerProxy<$ctype>;
        var result = macro null;
        var resolved = proxy.toType().sure().toComplex();
        var ident = resolved.toString();
        
        switch type.reduce() {
            case TInst(_.get() => cls, params):
                var fields = cls.fields.get();
                var field = null;
                for (f in fields) if (f.name == name) {
                    field = f;
                    break;
                }
                /*var tpath = 'WorkerProxy'.asTypePath([TPType(ctype)]);
                var ctor = if (!Context.defined('webworker')) {
                    macro new js.html.Worker('ww.js');
                } else {
                    /*var tp = type.getID(false).asTypePath();
                    macro new $tp();*/
                    /*self;
                }*/

                if (field != null) {
                    result = macro @:mergeBlock {
                        //trace('remote made');
                        /*var proxy:$proxy = new $tpath($ctor);
                        proxy.$name;*/
                        @:privateAccess $e{ident.resolve()}.inst.$name;
                    }

                } else {
                    Context.fatalError( 'Field $name was not found on $type.', self.pos );

                }

            case x:
                trace( x );
                Context.fatalError( 'Only classes are supported.', self.pos );

        }
        return result;
    }

}