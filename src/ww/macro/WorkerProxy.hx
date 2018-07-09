package ww.macro;

import haxe.macro.Type;
import haxe.macro.Expr;
import tink.macro.BuildCache;

using ww.macro.WorkerProxy;
using haxe.macro.Context;
using tink.MacroApi;

private enum abstract SConsts(String) to String {
    var Proxy = 'WorkerProxy';
    var WebWorker = 'webworker';
    var Debug = 'debug_workerproxy';
}

private typedef Data = {
    capture:Bool,
    ret:ComplexType,
    args:Array<FunctionArg>,
}

class WorkerProxy {

    static var isWebWorker = WebWorker.defined();
    static var WorkerLike = (macro:WorkerProxy.WorkerLike);
    static var keywords = ['postMessage', 'onmessage', 'onerror'];
    public static function build() {
        return BuildCache.getType(Proxy, function(ctx) {
            if (!ctx.type.unify( WorkerLike.toType().sure() )) {
                'Type parameter ${ctx.type.getID(false)} does not unify with ${WorkerLike.toType().sure().getID(false)}.'.fatalError( ctx.pos );
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
            var ctorType:ComplexType = isWebWorker ? ctype : WorkerLike;
            var eswitch = {expr:ESwitch(macro data.id, cases, macro {}), pos:ctx.pos};

            var ctorBody = if (isWebWorker) {
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

            var stype = isWebWorker ? macro:js.html.DedicatedWorkerGlobalScope : ctype;
            var sexpr = isWebWorker ? macro js.Syntax.code('self') : macro null;

            var definition = macro class $className {
                private static var counter = 0;
                //private static var scope = @:privateAccess WorkerChannel.scope;
                private static var scope:$stype = $sexpr;

                private var raw:$ctorType;
                private var self:$WorkerLike;
                private var cache:Map<String, tink.CoreApi.FutureTrigger<Dynamic>> = new Map();

                public function new(raw:$ctorType) {
                    $ctorBody;
                }

                public function onmessage(e:js.html.MessageEvent):Void {
                    $e{Debug.defined() ? macro @:privateAccess WorkerChannel.scope.console.log( $v{isWebWorker ? 'webworker' : 'ui thread'}, e.data ) : macro null};
                    var data:{id:String, values:Array<Any>, stamp:Float} = e.data;
                    $eswitch;
                }
            }

            definition.meta = [{name: isWebWorker?':worker':':main_thread', params:[], pos:ctx.pos}];
            definition.fields = definition.fields.concat( fields );

            if (Debug.defined()) {
                trace( new haxe.macro.Printer().printTypeDefinition(definition) );

            }

            return definition;
        });
    }

    private static function proxy(field:ClassField, data:Data):{bodies:Map<String, Expr>, cases:Array<Case>} {
        var ctype = data.ret;
        var name = field.name;
        var result = { bodies: new Map(), cases: [] };

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
            case FieldKind.FVar(r, w) if (isWebWorker):
                // webworker getter
                result.bodies.set( name, macro null );
                if (r.allowed()) {
                    result.bodies.set( 'get_$name', macro raw.$name );
                    result.cases.push( {
                        values: [macro $v{'get_$name'}],
                        guard: null,
                        expr: (macro [raw.$name]).proxyReply()
                    } );
                }

                // webworker setter
                if (w.allowed()) {
                    result.bodies.set( 'set_$name', macro v.next( r -> raw.$name = r ) );
                    result.cases.push( {
                        values: [macro $v{'set_$name'}],
                        guard: null,
                        expr: (macro [raw.$name = data.values[0]]).proxyReply(),
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
                        var stamp = js.Browser.window.performance.now() + (++counter * Math.random());
                        v.handle( o -> switch o {
                            case tink.CoreApi.Outcome.Success(r):
                                var data:{id:String, values:Array<Any>, stamp:Float} = {
                                    id:$v{'set_$name'},
                                    stamp: stamp,
                                    values:[r],
                                    }
                                self.postMessage( data );
                                cache.set(data.id + data.stamp, trigger);

                            case tink.CoreApi.Outcome.Failure(e):
                                trace( e );

                        } );
                        return trigger.asFuture();
                    } );

                }

                result.cases.push( 'set_$name'.proxyCheck(ctrigger, macro data.values[0]) );

            case FieldKind.FMethod(_) if (isWebWorker):
                var bodyArgs = [for (arg in data.args) macro $i{arg.name}];
                var caseArgs = [for (i in 0...data.args.length) macro data.values[$v{i}]];
                var caseBody = if (data.capture) {
                    (macro [raw.$name( $a{caseArgs} )]).proxyReply();
                } else {
                    macro @:mergeBlock {
                        raw.$name( $a{caseArgs} );
                        $e{(macro [tink.CoreApi.Noise.Noise]).proxyReply()};
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
                var args = data.args.map( arg -> macro $i{arg.name} );
                result.bodies.set( name, name.proxyWait(ctrigger, macro [$a{args}]) );
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

    private static function proxyWait(name:String, ctrigger:ComplexType, values:Expr):Expr {
        return macro {
            var trigger:tink.CoreApi.FutureTrigger<$ctrigger> = tink.CoreApi.Future.trigger();
            var stamp = js.Browser.window.performance.now() + (++counter * Math.random());
            var data:{id:String, values:Array<Any>, stamp:Float} = {
                id:$v{name}, stamp: stamp, values:$values,
            }
            self.postMessage( data );
            cache.set(data.id + data.stamp, trigger);
            return trigger.asFuture();
        }
    }

    private static function proxyTrigger(name:String, ctrigger:ComplexType):Expr {
        return macro @:mergeBlock {
            var trigger:tink.CoreApi.FutureTrigger<$ctrigger> = cast cache.get($v{name} + data.stamp);
            trigger.trigger(data.values[0]);
            cache.remove($v{name} + data.stamp);
        }
    }

    private static function proxyCheck(name:String, ctrigger:ComplexType, values:Expr):Case {
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

    private static function proxyReply(values:Expr):Expr {
        return macro scope.postMessage( {id:data.id, values:$values, stamp: data.stamp} );
    }

}