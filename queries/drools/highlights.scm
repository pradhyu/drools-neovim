;; queries/drools/highlights.scm
;; Tree-sitter highlight queries for Drools Rule Language

;; ---------------------------------------------------------------------------
;; Keywords
;; ---------------------------------------------------------------------------
[
  "package" "unit" "import" "global" "declare" "end"
  "rule" "query" "when" "then" "extends" "attributes"
  "trait" "enum" "entry-point" "window"
] @keyword

"function" @keyword.function

[ "from" "collect" "accumulate" "acc" "groupby" "eval" "over"
  "init" "action" "reverse" "result" ] @keyword

[ "and" "or" "not" "exists" "forall" ] @keyword.operator

[ "if" "else" "switch" "case" "default" "do" "break" ] @keyword.conditional
[ "for" "while" "continue" ] @keyword.repeat
[ "return" ] @keyword.return
[ "try" "catch" "finally" "throw" "throws" ] @keyword.exception
[ "new" "instanceof" ] @keyword.operator
[ "final" "static" "public" "private" "protected" "synchronized" ] @type.qualifier
[ "this" ] @variable.builtin

;; ---------------------------------------------------------------------------
;; Declarations
;; ---------------------------------------------------------------------------
(package_statement name: (scoped_identifier) @namespace)
(unit_statement name: (scoped_identifier) @namespace)
(import_statement name: (scoped_identifier) @include)

(rule_declaration name: (_) @label)
(query_declaration name: (_) @function)
(function_declaration name: (identifier) @function)
(function_declaration return_type: (type_spec) @type)

(global_declaration
  type: (type_spec) @type
  name: (identifier) @variable)

(declare_statement name: (_) @type.definition)
(field_declaration name: _ @property)
(field_declaration type: (type_spec) @type)
(enum_constant name: (identifier) @constant)

(attribute name: _ @attribute)
(annotation "@" @attribute name: (scoped_identifier) @attribute)

;; ---------------------------------------------------------------------------
;; LHS
;; ---------------------------------------------------------------------------
(fact_pattern type: (scoped_identifier) @type)
(oopath_segment field: (identifier) @property)
(oopath_segment cast: (scoped_identifier) @type)
(field_constraint field: (identifier) @property)
(variable_binding name: (_) @variable)
(query_call name: (_) @function.call)

(operator) @operator

(accumulate_function name: _ @function.builtin)

;; ---------------------------------------------------------------------------
;; RHS / Java
;; ---------------------------------------------------------------------------
(rhs_action name: _ @function.builtin)
(variable_declaration type: (type_spec) @type)
(parameter type: (type_spec) @type)
(parameter name: (_) @variable.parameter)
(new_expression (type_spec) @type)
(cast_expression (type_spec) @type)
(call_expression (expression (member_access (identifier) @method.call)))
(call_expression (expression (identifier) @function.call))
(member_access (identifier) @property)

(bound_variable) @variable

;; ---------------------------------------------------------------------------
;; Literals & comments
;; ---------------------------------------------------------------------------
(string) @string
(number) @number
(boolean) @boolean
(null_literal) @constant.builtin

(line_comment) @comment
(hash_comment) @comment
(block_comment) @comment
