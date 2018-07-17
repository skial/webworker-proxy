package ww.macro;

import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;
import ww.macro.Utils.runners;
import ww.macro.Utils.checkers;
import tink.macro.BuildCache;

using StringTools;
using ww.macro.WorkerProxy;
using haxe.macro.Context;
using tink.MacroApi;

private enum abstract SConsts(String) to String {
    var Proxy = 'WorkerProxy';
}

private typedef Data = {
    capture:Bool,
    ret:ComplexType,
    args:Array<FunctionArg>,
}

private abstract C(ComplexType) from ComplexType to ComplexType {
    public static var Transferable(get, never):C;
    static function get_Transferable():C return macro:Transferable<Any>;

    public static var WorkerLike(get, never):C;
    static function get_WorkerLike():C return macro:WorkerProxy.WorkerLike;

    @:to public function toType():haxe.macro.Type {
        return this.toType().sure();
    }

    @:to function asString():String {
        return toType().getID(false);
    }
}

class WorkerProxy {

    static var keywords = ['postMessage', 'onmessage', 'onerror'];
    public static function build() {
        return BuildCache.getType(Proxy, function(ctx:BuildContext) {
            if (!ctx.type.unify( C.WorkerLike )) {
                'Type parameter ${ctx.type.getID(false)} does not unify with ${C.WorkerLike}.'.fatalError( ctx.pos );
            }

            var cases:Array<Case> = [];
            var fields:Array<Field> = [];
            var ctype = ctx.type.toComplex();
            var tfields:Array<ClassField> = [];
            //var tstatics:Array<ClassField> = [];

            switch ctx.type.reduce() {
                case TInst(_.get() => cls, p):
                    tfields = cls.fields.get();
                    //tstatics = cls.statics.get();

                case x:
                    'Unsupported type ${x.getID(false)}.'.fatalError( ctx.pos );

            }

            var fs = tfields.map( f -> {f:f, s:false});
            // Statics are excluded from the proxy class.
            //fs = fs.concat( tstatics.map( f -> {f:f, s:true} ) );

            for (f in fs) if (f.f.isPublic) {
                var field = f.f;
                if (keywords.indexOf(field.name) == -1) {
                    var data:Data = {args:[], ret:null, capture:true};
                    
                    switch field.type.reduce() {
                        case TFun(args, ret):
                            data.ret = ret.toComplex();
                            data.args = args.map( a -> ({name:a.name, type:a.t.toComplex(), opt:a.opt}:FunctionArg) );
                            
                            switch data.ret {
                                case TPath(obj) if(obj.name == 'Void' || obj.sub == 'Void'):
                                    data.ret = macro:tink.CoreApi.Noise;
                                    data.capture = false;

                                case _:
                            }

                        case _:
                            data.ret = field.type.toComplex();
                            data.args.push( {name:'v', type:data.ret, opt:false} );
                    }


                    var cret = data.ret;
                    var ctrigger = data.ret;
                    
                    switch (macro tink.CoreApi.Promise.lift((null:$cret))).typeof() {
                        case Success(type): cret = type.toComplex();
                        case Failure(error): trace(error); 
                    }

                    switch ( macro ww.macro.Utils.unwrap(tink.CoreApi.Promise.lift((null:$cret))) ).typeof() {
                        case Success(type): ctrigger = type.toComplex();
                        case Failure(error): trace(error);
                    }

                    var pair = field.proxy(data);

                    cases = cases.concat( pair.cases );

                    for (name in pair.bodies.keys()) {
                        switch field.kind {
                            case FVar(_, _) if (name == field.name):
                                var getter = 'get_$name';
                                var setter = 'set_$name';
                                var newFields = (macro class Tmp {
                                    public var $name:$cret;
                                    private function $getter():$cret {
                                        return @:mergeBlock $e{pair.bodies.exists(getter) ? pair.bodies.get(getter) : macro null};
                                    }
                                    private function $setter(v:$cret):$cret {
                                        return @:mergeBlock $e{pair.bodies.exists(setter) ? pair.bodies.get(setter) : macro null};
                                    }
                                }).fields;

                                switch newFields[0].kind {
                                    case FVar(t, _):
                                        newFields[0].kind = FProp(
                                            pair.bodies.exists(getter) ? 'get' : 'null',
                                            pair.bodies.exists(setter) ? 'set' : 'null',
                                            t, null
                                        );

                                    case _:
                                }

                                fields.push( newFields[0] );
                                if (pair.bodies.exists(getter)) fields.push( newFields[1] );
                                if (pair.bodies.exists(setter)) fields.push( newFields[2] );

                            case FMethod(_):
                                var newFields = (macro class Tmp {
                                    public function $name():$cret return $e{pair.bodies.get(name)};
                                }).fields;

                                switch newFields[0].kind {
                                    case FFun(method): method.args = data.args;
                                    case _:
                                }

                                fields.push( newFields[0] );

                            case _:

                        }

                    }

                }

            }

            var className = ctx.name;
            var ctorType:ComplexType = WebWorker ? ctype : C.WorkerLike;
            var eswitch = {expr:ESwitch(macro data.id, cases, macro {}), pos:ctx.pos};

            var ctorBody = if (WebWorker) {
                macro @:mergeBlock {
                    this.raw = raw;
                    self = raw;
                    scope.onmessage = this.onmessage;
                }
            } else {
                macro @:mergeBlock {
                    self = raw;
                    self.onmessage = this.onmessage;
                }
            }

            var stype = WebWorker ? macro:js.html.DedicatedWorkerGlobalScope : ctype;
            var sexpr = WebWorker ? macro js.Syntax.code('self') : macro null;
            var cworker = C.WorkerLike;

            var definition = macro class $className {
                private static var counter = 0;
                //private static var scope = @:privateAccess WorkerChannel.scope;
                private static var scope:$stype = $sexpr;

                private var raw:$ctorType;
                private var self:$cworker;
                private var cache:Map<String, tink.CoreApi.FutureTrigger<Dynamic>> = new Map();

                public function new(raw:$ctorType) {
                    $ctorBody;
                }

                public function onmessage(e:js.html.MessageEvent):Void {
                    $e{WWP_Debug ? macro @:privateAccess WorkerChannel.scope.console.log( $v{WebWorker ? 'webworker' : 'ui thread'}, e.data ) : macro null};
                    var data:{id:String, values:Array<Any>, stamp:Float} = e.data;
                    $eswitch;
                }
            }

            definition.meta = [{name: WebWorker?':worker':':main_thread', params:[], pos:ctx.pos}];
            definition.fields = definition.fields.concat( fields );

            if (WWP_Debug) {
                trace( new haxe.macro.Printer().printTypeDefinition(definition) );

            }

            return definition;
        });
    }

    private static function proxy(field:ClassField, data:Data):{bodies:Map<String, Expr>, cases:Array<Case>} {
        var ctype = data.ret;
        var name = field.name;
        var movable = ctype.isTransferable();
        var result = { bodies: new Map(), cases: [] };

        if (WWP_Debug.defined()) trace( ctype );

        switch (macro tink.CoreApi.Promise.lift((null:$ctype))).typeof() {
            case Success(t): ctype = t.toComplex();
            case Failure(e): trace( e );
        }
        
        var ctrigger = ctype;

        switch ( macro ww.macro.Utils.unwrap(tink.CoreApi.Promise.lift((null:$ctype))) ).typeof() {
            case Success(t): ctrigger = t.toComplex();
            case Failure(e): trace( e );
        }

        switch field.kind {
            case FieldKind.FVar(r, w) if (WebWorker.defined()):
                // webworker getter
                result.bodies.set( name, macro null );
                if (r.allowed()) {
                    result.bodies.set( 'get_$name', macro raw.$name );
                    result.cases.push( {
                        values: [macro $v{'get_$name'}],
                        guard: null,
                        expr: (macro [raw.$name]).proxyReply(movable)
                    } );
                }

                // webworker setter
                if (w.allowed()) {
                    result.bodies.set( 'set_$name', macro v.next( r -> raw.$name = r ) );
                    result.cases.push( {
                        values: [macro $v{'set_$name'}],
                        guard: null,
                        expr: (macro [raw.$name = data.values[0]]).proxyReply(movable),
                    } );
                }

            case FieldKind.FVar(r, w):
                result.bodies.set( name, macro null );
                // main thread getter
                if (r.allowed()) {
                    result.bodies.set( 'get_$name', 'get_$name'.proxyWait(ctrigger, macro []) );
                    result.cases.push( 'get_$name'.proxyCheck(ctrigger, macro data.values[0]) );

                }
                
                // main thread setter
                if (w.allowed()) {
                    result.bodies.set( 'set_$name', macro {
                        var trigger:tink.CoreApi.FutureTrigger<$ctrigger> = tink.CoreApi.Future.trigger();
                        var stamp = ${runners[runners.length-1].timeStamp()} + (++counter * Math.random());
                        v.handle( o -> switch o {
                            case tink.CoreApi.Outcome.Success(r):
                                var data:{id:String, values:Array<Any>, stamp:Float} = {
                                    id:$v{'set_$name'},
                                    stamp: stamp,
                                    values:[r],
                                }
                                $e{(macro data).proxyReply(movable)};
                                cache.set(data.id + data.stamp, trigger);

                            case tink.CoreApi.Outcome.Failure(e):
                                trace( e );

                        } );
                        return trigger.asFuture();
                    } );

                }

                result.cases.push( 'set_$name'.proxyCheck(ctrigger, macro data.values[0]) );

            case FieldKind.FMethod(_) if (WebWorker.defined()):
                var bodyArgs = [for (arg in data.args) macro $i{arg.name}];
                //var caseArgs = [for (i in 0...data.args.length) macro data.values[$v{i}]];
                var caseArgs = [];
                for (i in 0...data.args.length) if(data.args[i].type != null && data.args[i].type.isTransferable()){
                    caseArgs.push( runners[runners.length-1].decode(macro data.values[$v{i}], {}) );
                } else {
                    caseArgs.push( macro data.values[$v{i}] );
                };
                var caseBody = if (data.capture) {
                    macro @:mergeBlock {
                        @:reply1 var result = $e{runners[runners.length-1].encode(macro raw.$name( $a{caseArgs}), {})};
                        //trace( result );
                        $e{(macro [result]).proxyReply(movable)};
                    }
                } else {
                    macro @:mergeBlock {
                        raw.$name( $a{caseArgs} );
                        @:reply2 $e{(macro [tink.CoreApi.Noise.Noise]).proxyReply()};
                    }
                }
                
                result.bodies.set( name, 
                    data.capture 
                        ? macro raw.$name($a{bodyArgs}) 
                        : macro @:mergeBlock {
                            raw.$name($a{bodyArgs});
                            tink.CoreApi.Noise.Noise;
                        }
                );
                result.cases.push({ values: [macro $v{name}], guard: null, expr: caseBody });

            case FieldKind.FMethod(_):
                var args = [];
                var movables = [];

                for (idx in 0...data.args.length) {
                    var arg = data.args[idx];

                    if (arg.type != null && arg.type.isTransferable()) {
                        args.push( runners[runners.length-1].encode(macro $i{arg.name}, {}) );
                        movables.push( macro data.values[$v{idx}] );

                    } else {
                        args.push( macro $i{arg.name} );

                    }

                }

                result.bodies.set( name, name.proxyWait(ctrigger, macro [$a{args}], movables.length > 0 ? macro [$a{movables}] : null) );
                result.cases.push({
                    values: [macro $v{name}],
                    guard: macro cache.exists($v{name} + data.stamp),
                    expr: name.proxyTrigger(ctrigger),
                });

            case _:

        }

        return result;
    }

    private static function allowed(v:VarAccess):Bool {
        return !v.match(AccNo | AccNever | AccCtor);
    }

    private static function proxyWait(name:String, ctrigger:C, values:Expr, ?movables:Expr):Expr {
        return macro {
            var trigger:tink.CoreApi.FutureTrigger<$ctrigger> = tink.CoreApi.Future.trigger();
            var stamp = $e{runners[runners.length-1].timeStamp()} + (++counter * Math.random());
            var data:{id:String, values:Array<Any>, stamp:Float} = {
                id:$v{name}, stamp: stamp, values:$values,
            }
            $e{movables == null ? macro self.postMessage( data ) : macro self.postMessage( data, $movables )};
            cache.set(data.id + data.stamp, trigger);
            return trigger.asFuture();
        }
    }

    private static function proxyTrigger(name:String, ctrigger:C):Expr {
        var movable = ctrigger.isTransferable();
        var unwrapped = movable ? ctrigger.unwrapTransfer() : ctrigger;
        return macro @:mergeBlock {
            var trigger:tink.CoreApi.FutureTrigger<$ctrigger> = cast cache.get($v{name} + data.stamp);
            trigger.trigger($e{runners[runners.length-1].decode(macro data.values[0], {})});
            cache.remove($v{name} + data.stamp);
        }
    }

    private static function proxyCheck(name:String, ctrigger:C, values:Expr):Case {
        return {
            values: [macro $v{name}],
            guard: macro cache.exists($v{name} + data.stamp),
            expr: macro @:mergeBlock {
                var trigger:tink.CoreApi.FutureTrigger<$ctrigger> = cast cache.get($v{name} + data.stamp);
                trigger.trigger($values);
                cache.remove($v{name} + data.stamp);
            }
        }
    }

    private static function proxyReply(values:Expr, transfer:Bool = false):Expr {
        return transfer
        ? macro scope.postMessage( {id:data.id, values:$values, stamp:data.stamp}, $values )
        : macro scope.postMessage( {id:data.id, values:$values, stamp:data.stamp} );
    }

    private static function isTransferable(c:C):Bool {
        /*trace(c.toString());
        trace( c.toString(), '$c'.startsWith('Transferable') );*/
        return '$c'.startsWith('Transferable');
        //trace( (macro ww.macro.Utils.unwrap((null:$c))).typeof().sure().unify( C.Transferable ) );
        //return (macro ww.macro.Utils.unwrap((null:$c))).typeof().sure().unify( (macro:Transferable<haxe.io.Bytes>).toType().sure() );
    }

    private static function unwrapTransfer(c:C):ComplexType {
        /*trace(c.toString());
        trace(c.unify(C.Transferable));
        trace( (macro (null:$c)).is(c) );
        trace( (macro Transferable.of((null:$c))).typeof().sure().getID(false) );
        trace( '$c', '$c'.startsWith('Transferable') );*/
        //return try (macro (null:$c).unwrap()).typeof().sure().toComplex() catch(e:Any) c;
        return '$c'.startsWith('Transferable') 
            ? (macro (null:$c).unwrap()).typeof().sure().toComplex()
            : c;
    }

}