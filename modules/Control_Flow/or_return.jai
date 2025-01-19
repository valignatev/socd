/*
NOTES: 
- Support nested or_return?, or maybe make it a nice compile error.

*/

default_of_type_as_string :: (ti: *Type_Info) -> string {
    result: string;
    if ti.type == {
        case .INTEGER; result = "0";
        case .BOOL; result = "false";
        case .FLOAT; result = "0.0";
        // Maybe it's better to return New(pointer_to) and leak a bit instead of returning a null pointer?
        case .POINTER; return "null";
        case .PROCEDURE; result = "null"; // TODO: Maybe do something fancier here...
        case .VOID; Compiler.compiler_report("or_return doesn't support procedures that return void (but it does support *void)");
        case .STRUCT; result = ".{}";
        case .ARRAY; result = ".[]";
        case .ENUM; {
            // Should we straight up return 0 in this case instead of the first value,
            // even if it could be an invalid variant?
            our_enum := cast(*Type_Info_Enum)ti;
            result = tprint(".%", our_enum.names[0]);
        }
        case .TYPE; result = "Type";
        case .CODE; result = "Code.{}";
    }
    return result;
}

// TODO: We're completely disrespecting #must here. There's no way to set #must in modify, so we need to improve our message loop
or_return_inner :: ($code_returns: int, $code: Code, $outer_proc_header: Code = (#code dummy), $declared_named_returns: ..string) -> string #expand {
    return #run -> string {
        root, expressions := Compiler.compiler_get_nodes(code);

        outer := Compiler.compiler_get_nodes(outer_proc_header);

        if outer.kind != .IDENT {
            return "";
        }

        ident := cast(*Compiler.Code_Ident)outer;

        if ident.name == "dummy" {
            return "";
        }

        outer_header := cast(*Compiler.Code_Procedure_Header)ident.*.resolved_declaration.expression;
        outer_returns := outer_header.returns;
        outer_builder: String_Builder;

        for outer_returns {

            if it.entry.name {
                if array_find(declared_named_returns, it.entry.name) {
                    print_to_builder(*outer_builder, "%", it.entry.name);
                } else {
                    print_to_builder(*outer_builder, "%=%", it.entry.name, default_of_type_as_string(it.entry.base.type));
                }
            } else {
                to_print := default_of_type_as_string(it.entry.base.type);
                append(*outer_builder, to_print);
            }
            if it_index < outer_returns.count - 1 {
                append(*outer_builder, ", ");
            }
        }
        outer_returns_formatted := builder_to_string(*outer_builder);

        if root.kind != .PROCEDURE_CALL {
            Compiler.compiler_report(
                "or_return macro only supports procedure_calls",
            );
            return "";
        }

        call := cast(*Compiler.Code_Procedure_Call)root;
        proc_expr := call.resolved_procedure_expression;

        if proc_expr.kind != .PROCEDURE_HEADER {
            Compiler.compiler_report(
                "Unexpected resolved procedure expression",
            );
            return "";
        }

        code_proc_header := cast(*Compiler.Code_Procedure_Header)proc_expr;

        return_values := code_proc_header.returns;

        builder: String_Builder;
        count := 0;
        append(*builder, "{\n");
        for return_values {
            print_to_builder(*builder, "ret%", it_index + 1);
            if it_index < return_values.count - 1 {
                append(*builder, ", ");
            } else {
                append(*builder, " := ");
            }
            count += 1;
        }

        print_expression(*builder, root);
        append(*builder, ";\n");

        print_to_builder(*builder, "if !ret% `return %;\n", return_values.count, outer_returns_formatted);
        print_to_builder(*builder, "return ");

        for return_values {
            print_to_builder(*builder, "ret%", it_index + 1);
            if it_index < return_values.count - 1 {
                append(*builder, ", ");
            }
        }
        append(*builder, ";");
        append(*builder, "\n}\n");

        result_code := builder_to_string(*builder);

        return result_code;
    };
}

#scope_file

#import "Code_Visit";
#import "Basic";
#import "String";
#import "Program_Print";
using Compiler :: #import "Compiler";
