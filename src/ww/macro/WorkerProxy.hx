package ww.macro;

import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;
import ww.macro.Utils.runners;
import tink.macro.BuildCache;

using StringTools;
using ww.macro.WorkerProxy;
using haxe.macro.Context;
using tink.MacroApi;

private enum abstract SConsts(String) to String {
    var Proxy = 'WorkerProxy';
}

private abstract E(Array<String>->String) from Array<String>->String {
    public inline static function TypeUnify(args:Array<String>):String return 'Type parameter ${args[0]} does not unify with ${args[1]}.';
    public inline static function Unsupported(args:Array<String>):String return 'Unsupported type ${args[0]}.';
}

private abstract C(ComplexType) from ComplexType to ComplexType {
    public static var WorkerLike(get, never):C;
    static function get_WorkerLike():C return macro:WorkerProxy.WorkerLike;

    @:to public function toType():haxe.macro.Type return this.toType().sure();
    @:to function asString():String return this.toType().sure().getID(false);

}

class WorkerProxy {

    static var keywords = ['postMessage', 'onmessage', 'onerror'];
    public static function build() {
        return BuildCache.getType(Proxy, function(ctx:BuildContext) {
            if (!ctx.type.unify( C.WorkerLike )) 
                E.TypeUnify([ctx.type.getID(false), C.WorkerLike]).fatalError(ctx.pos);

            var cases:Array<Case> = [];
            var fields:Array<Field> = [];
            var ctype = ctx.type.toComplexType();
            var tfields:Array<ClassField> = [];
            
            switch ctx.type.reduce() {
                case TInst(_.get() => cls, p): tfields = cls.fields.get();
                case x: E.Unsupported([x.getID(false)]).fatalError(ctx.pos);
            }

            for (field in tfields) if (field.isPublic) {
                if (keywords.indexOf(field.name) == -1) {
                    var data:Info = {args:[], capture:true, isMovable:false, isPromise:false, ret:null, trigger:null};
                    
                    switch field.type.reduce() {
                        case TFun(args, ret):
                            data.ret = data.trigger = ret.toComplex();
                            data.args = args.map( a -> ({name:a.name, type:a.t.toComplex(), opt:a.opt}:FunctionArg) );
                            
                            switch data.ret {
                                case TPath(obj) if(obj.name == 'Void' || obj.sub == 'Void'):
                                    data.ret = data.trigger = macro:tink.CoreApi.Noise;
                                    data.capture = false;

                                case _:
                            }

                        case _:
                            data.ret = data.trigger = field.type.toComplex();
                            data.args.push( {name:'v', type:data.ret, opt:false} );
                    };
                    
                    data.isMovable = data.ret.isTransferable();
                    data.isPromise = data.ret.isPromised();
                    var cret = data.ret;
                    var ctrigger = data.ret;
                    switch (macro tink.CoreApi.Promise.lift((null:$cret))).typeof() {
                        case Success(type): cret = data.ret = type.toComplex();
                        case Failure(error): trace(error);
                    }

                    switch ( macro ww.macro.Utils.unwrap(tink.CoreApi.Promise.lift((null:$cret))) ).typeof() {
                        case Success(type): data.trigger = ctrigger = type.toComplex();
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
                    if (scope.onmessage == null) {
                        scope.onmessage = this.onmessage;

                    } else {
                        // Store old function incase multiple workerproxies have been compiled to a single file.
                        var oldOnMessage = scope.onmessage;
                        scope.onmessage = e -> {
                            this.onmessage(e);
                            oldOnMessage(e);
                        }

                    }
                }
            } else {
                macro @:mergeBlock {
                    self = raw;
                    self.onmessage = this.onmessage;
                }
            }

            var cworker = C.WorkerLike;
            var self = ctx.name.asComplexType();

            var definition = macro class $className {
                private static var counter = 0;

                private var raw:$ctorType;
                private var self:$cworker;
                private var cache:Map<String, tink.CoreApi.FutureTrigger<Dynamic>> = new Map();

                @:isVar private static var inst(default, set):$self;
                private static function set_inst(v:$self):$self {
                    if (inst == null) inst = v;
                    return inst;
                }

                public function new(raw:$ctorType) {
                    $ctorBody;
                    inst = this;
                }

                public function onmessage(e:js.html.MessageEvent):Void {
                    $e{WWP_Debug ? macro @:privateAccess WorkerChannel.scope.console.log( $v{WebWorker ? 'webworker' : 'ui thread'}, e.data ) : macro null};
                    var data:{id:String, values:Array<Any>, stamp:Float} = e.data;
                    $eswitch;
                }
            }
            
            definition.meta = [{name: WebWorker?':worker':':main_thread', params:[], pos:ctx.pos}];
            definition.fields = definition.fields.concat( fields.concat( runners[runners.length-1].extraFields(ctx) ) );

            if (WWP_Debug) {
                trace( new haxe.macro.Printer().printTypeDefinition(definition) );

            }

            return definition;
        });
    }

    private static function proxy(field:ClassField, data:Info):{bodies:Map<String, Expr>, cases:Array<Case>} {
        var ctype = data.ret;
        var name = field.name;
        var ctrigger = data.trigger;
        var result = { bodies: new Map(), cases: [] };
        if (WWP_Debug.defined()) trace( ctype );
        
        switch field.kind {
            case FieldKind.FVar(r, w) if (WebWorker.defined()):
                // webworker getter
                result.bodies.set( name, macro null );
                if (r.allowed()) {
                    result.bodies.set( 'get_${name}', macro raw.$name );
                    result.cases.push( {
                        guard: null,
                        values: [macro $v{'get_${name}'}],
                        expr: (macro [raw.$name]).proxyReply(data)
                    } );

                }

                // webworker setter
                if (w.allowed()) {
                    result.bodies.set( 'set_${name}', macro v.next( r -> raw.$name = r ) );
                    result.cases.push( {
                        guard: null,
                        values: [macro $v{'set_${name}'}],
                        expr: (macro [raw.$name = data.values[0]]).proxyReply(data),
                    } );

                }

            case FieldKind.FVar(r, w):
                result.bodies.set( name, macro null );
                // main thread getter
                if (r.allowed()) {
                    result.bodies.set( 'get_${name}', 'get_${name}'.proxyWait(macro [], data) );
                    result.cases.push( 'get_${name}'.proxyCheck(ctrigger, macro data.values[0]) );

                }
                
                // main thread setter
                if (w.allowed()) {
                    result.bodies.set( 'set_${name}', macro {
                        var trigger:tink.CoreApi.FutureTrigger<$ctrigger> = tink.CoreApi.Future.trigger();
                        var stamp = ${runners[runners.length-1].timeStamp()} + (++counter * Math.random());
                        v.handle( o -> switch o {
                            case tink.CoreApi.Outcome.Success(r):
                                var data:{id:String, values:Array<Any>, stamp:Float} = {
                                    id:$v{'set_${name}'},
                                    stamp: stamp,
                                    values:[r],
                                }
                                $e{(macro data).proxyReply(data)};
                                cache.set(data.id + data.stamp, trigger);

                            case tink.CoreApi.Outcome.Failure(e):
                                trace( e );

                        } );
                        return trigger.asFuture();
                    } );

                }

                result.cases.push( 'set_${name}'.proxyCheck(ctrigger, macro data.values[0]) );

            case FieldKind.FMethod(_) if (WebWorker.defined()):
                var caseArgs = [];
                var bodyArgs = [for (arg in data.args) macro $i{arg.name}];

                for (i in 0...data.args.length) {
                    var type = data.args[i].type;
                    type != null && type.isTransferable() 
                        ? caseArgs.push( runners[runners.length-1].decode( macro data.values[$v{i}], {isPromise:false, isMovable:true, capture:true, ret:type, args:[], trigger:type.unwrapTransfer()} ) )
                        : caseArgs.push( macro data.values[$v{i}] );
                }
                
                var caseBody = switch [data.capture, data.isPromise] {
                    case [true, true]:
                        macro @:mergeBlock {
                            raw.$name( $a{caseArgs} ).handle( o -> switch o {
                                case tink.CoreApi.Outcome.Success(v):
                                    @:reply1a var result = $e{runners[runners.length-1].encode(macro v, data)};
                                    @:reply1b $e{(macro [result]).proxyReply(data)};

                                case tink.CoreApi.Outcome.Failure(e): 
                                    trace( e );

                            } );
                        }
                    case [false, true]:
                        macro @:mergeBlock {
                            raw.$name( $a{caseArgs} ).handle( o -> switch o {
                                case tink.CoreApi.Outcome.Success(v):
                                    @:reply2 $e{(macro [tink.CoreApi.Noise.Noise]).proxyReply(data)};

                                case tink.CoreApi.Outcome.Failure(e):
                                    trace( e );

                            } );
                        }

                    case [true, false]:
                        macro @:mergeBlock {
                            @:reply1a var result = $e{runners[runners.length-1].encode(macro raw.$name( $a{caseArgs}), data)};
                            @:reply1b $e{(macro [result]).proxyReply(data)};
                        }
                    case [false, false]:
                        macro @:mergeBlock {
                            raw.$name( $a{caseArgs} );
                            @:reply2 $e{(macro [tink.CoreApi.Noise.Noise]).proxyReply(data)};
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

                for (idx in 0...data.args.length) {
                    var arg = data.args[idx];

                    if (arg.type != null && arg.type.isTransferable()) {
                        var data:Info = {isPromise:false, isMovable:true, ret:arg.type, args:[], capture:true, trigger:arg.type.unwrapTransfer()};
                        args.push( macro @:move $e{runners[runners.length-1].encode(macro $i{arg.name}, data)} );

                    } else {
                        args.push( macro $i{arg.name} );

                    }

                }

                result.bodies.set( name, name.proxyWait(macro [$a{args}], data) );
                result.cases.push({
                    values: [macro $v{name}],
                    expr: name.proxyTrigger(data),
                    guard: macro cache.exists($v{name} + data.stamp),
                });

            case _:

        }

        return result;
    }

    private static function allowed(v:VarAccess):Bool {
        return !v.match(AccNo | AccNever | AccCtor);
    }

    private static function proxyWait(name:String, values:Expr, info:Info):Expr {
        var ctrigger:C = info.trigger;
        return macro {
            var trigger:tink.CoreApi.FutureTrigger<$ctrigger> = tink.CoreApi.Future.trigger();
            var stamp = $e{runners[runners.length-1].timeStamp()} + (++counter * Math.random());
            var data:{id:String, values:Array<Any>, stamp:Float} = { id:$v{name}, stamp:stamp, values:$values };
            $e{ runners[runners.length-1].send( macro data, info ) };
            cache.set(data.id + data.stamp, trigger);
            return trigger.asFuture();
        }
    }

    private static function proxyTrigger(name:String, data:Info):Expr {
        var ctrigger = data.trigger;
        return macro @:mergeBlock {
            var trigger:tink.CoreApi.FutureTrigger<$ctrigger> = cast cache.get($v{name} + data.stamp);
            trigger.trigger($e{runners[runners.length-1].decode(macro data.values[0], data)});
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

    private static function proxyReply(values:Expr, info:Info):Expr {
        return runners[runners.length-1].reply( macro {id:data.id, values:$values, stamp:data.stamp}, info );
    }

    private static function isTransferable(c:C):Bool {
        return '$c'.startsWith('Transferable');
    }

    private static function isPromised(c:C):Bool {
        return c.toString().toLowerCase().startsWith('tink.coreapi.promise')
        || c.toString().toLowerCase().startsWith('tink.coreapi.future');
    }

    private static function unwrapTransfer(c:C):ComplexType {
        return '$c'.startsWith('Transferable') 
            ? (macro (null:$c).unwrap()).typeof().sure().toComplex()
            : c;
    }

}