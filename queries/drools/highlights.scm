;; queries/drools/highlights.scm
;; Tree-sitter highlight queries for Drools Rule Language

(rule_declaration
  name: (string) @keyword.rule.name) @keyword.rule

(package_statement
  name: (scoped_identifier) @namespace)

(import_statement
  name: (scoped_identifier) @include)

(global_declaration
  type: (type_identifier) @type
  name: (identifier) @variable)

(declare_statement
  name: (type_identifier) @type.definition)

(query_declaration
  name: (string) @function)

(attribute
  name: (identifier) @attribute)

(conditional_element
  kind: ["when" "then" "and" "or" "not" "exists" "forall" "eval" "from" "over"] @keyword.conditional)

(operator
  ["matches" "contains" "memberOf" "soundslike" "in" "excludes"] @operator)

(variable_binding
  name: (identifier) @variable)

(line_comment) @comment
(block_comment) @comment
(string) @string
(number) @number
(boolean) @boolean
