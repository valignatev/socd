// You can call this if your build script doesn't have a custom message loop
// Call this after compiler_begin_intercept and after adding your build file
or_return_build :: (w: Workspace) {
    or_return_add_source(w);

    while true {
        message := compiler_wait_for_message();
        if message.kind == {
        case .TYPECHECKED;
            typechecked := cast(*Message_Typechecked) message;
            or_return_handle_typechecked(typechecked);

        case .COMPLETE;
            break;
        }
    }
}

// Call this inside of your metaprogram loop.
or_return_handle_typechecked :: (typechecked: *Message_Typechecked) {
    for to: typechecked.procedure_bodies {
        body := to.expression;
        if body.body_flags & .ALREADY_MODIFIED {
            continue;
        }

        assert(body.block != null);
        block := body.block;
        declared_named_returns: [..]string;
        header_returns := body.header.returns;
        for statement: block.statements {
            sub_expressions: [..]*Code_Node;
            get_recursive_nodes_breadth_first(statement, *sub_expressions);
            for sub_expressions {

                if it.kind == .DECLARATION {
                    decl := cast(*Code_Declaration)it;
                    name := decl.entry.name;
                    for header_returns {
                        if it.name && it.name == name && decl.expression {
                            array_add(*declared_named_returns, copy_string(name));
                        }
                    }
                }
                if it.kind != .PROCEDURE_CALL {
                    continue;
                }
                call := cast(*Code_Procedure_Call)it;

                ident := cast(*Code_Ident)call.procedure_expression;

                if ident.name != "or_return" {
                    continue;
                }

                or_return_call_args: [..]Code_Argument;
                first_arg := call.arguments_unsorted[0];
                array_add(*or_return_call_args, first_arg);

                {

                    ident := New(Code_Ident);
                    ident.name = body.header.name;
                    decl := New(Code_Declaration);
                    decl.expression = body.header;
                    ident.resolved_declaration = decl;

                    arg := New(Code_Argument);
                    arg.expression = ident;
                    array_add(*or_return_call_args, arg);

                    for declared_named_returns {
                        literal := New(Code_Literal);
                        literal.value_type = .STRING;
                        literal._string = it;

                        arg := New(Code_Argument);
                        arg.expression = literal;
                        array_add(*or_return_call_args, arg);
                    }
                }

                call.arguments_unsorted = or_return_call_args;
                compiler_modify_procedure(typechecked.workspace, body);
            }
        }
    }
}

OR_RETURN_TEMPLATE :: #string DONE_FR
or_return :: ($code: Code, $outer_proc_header: Code = (#code dummy), $declared_named_returns: ..string) -> %1 #expand
#modify {
    root, expressions := Compiler.compiler_get_nodes(code);
    if root.kind != .PROCEDURE_CALL {
        return false, "or_return macro only supports procedure_calls";
    }

    call := cast(*Compiler.Code_Procedure_Call)root;
    proc_expr := call.resolved_procedure_expression;

    if proc_expr.kind != .PROCEDURE_HEADER {
        return false, "Unexpected resolved procedure expression";
    }

    header := cast(*Compiler.Code_Procedure_Header)proc_expr;

    return_values := header.returns.count;
    if return_values != %4 {
        return false, tprint("Procedure should have exactly %5 return values, but it has %5", %4, return_values);
    }

    last_return := header.returns[return_values-1].type_inst;
    last_return_type := Compiler.get_type(last_return.result);
    ti := cast(*Type_Info)last_return_type;
    if ti.type == .STRUCT {
        return false, tprint("The last return value of the procedure `%5` passed to or_return is a struct `%5`.\nStructs can't be evaluated as booleans, so or_return doesn't support them.", header.name, last_return_type);
    }

    %2

    for 0..return_values - 1 {
        return_ := header.returns[it].type_inst;
        return_type := Compiler.get_type(return_.result);
        %3
    }

    return true;
} {
    #insert,scope(code) -> string {
        return or_return_inner(%4, code, outer_proc_header, ..declared_named_returns);
    }
}

DONE_FR

or_return_add_source :: (w: Workspace) {
    for 1..10 {
        returns_array: [..]string;
        defaults_array: [..]string;
        designators_array: [..]string;
        returns: string;
        defaults: string;
        designators: string;

        for 1..it {
            array_add(*returns_array, tprint("$T%", it));
            array_add(*defaults_array, tprint("T%", it));
            array_add(*designators_array, tprint("if it == % T% = return_type;", it - 1, it));
        }
        returns = join(..returns_array, ", ");
        defaults = tprint("% = bool;", join(..defaults_array, ", "));
        designators = join(..designators_array, "\n        ");
        add_build_string(tprint(OR_RETURN_TEMPLATE, returns, defaults, designators, it, "%"), w);
    }
    add_build_string("Compiler :: #import \"Compiler\";", w);
}

// Experimental metaprogram plugin, ignore this for now.
add_source :: (p: *Metaprogram_Plugin)  {
    plugin := cast(*Or_Return_Plugin) p;
    w := p.workspace;
    assert(w >= 0);

    inline or_return_add_source(w);
}

message :: (p: *Metaprogram_Plugin, message: *Message) {
    plugin := cast(*Or_Return_Plugin) p;

    if message.kind != .TYPECHECKED return;

    typechecked := cast(*Message_Typechecked) message;
    inline or_return_handle_typechecked(typechecked);
}

shutdown :: (p: *Metaprogram_Plugin) {
    free(p);
}

get_plugin :: () -> *Metaprogram_Plugin {
    p := New(Or_Return_Plugin);
    p.add_source = add_source;
    p.message = message;
    p.shutdown = shutdown;

    return p;
}

Or_Return_Plugin :: struct {
    #as using base: Metaprogram_Plugin;
}

#scope_file

#import "Basic";
#import "Compiler";
#import "Code_Visit";
#import "String";
