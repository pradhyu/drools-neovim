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
  kind: ["when" "then" "and" "or" "not" "exists" "forall" "eval" "from" "over" "unit" "extends"] @keyword.conditional)

(operator
  ["matches" "contains" "memberOf" "soundslike" "in" "excludes" "after" "before" "coincides" "during" "finishes" "finishedby" "meets" "metby" "overlaps" "overlappedby" "starts" "startedby"] @operator)

(accumulate_function
  name: ["sum" "avg" "min" "max" "count" "collectList" "collectSet" "collectArray"] @function.builtin)

(variable_binding
  name: (identifier) @variable)

(fact_pattern
  type: (type_identifier) @type)

(field_constraint
  field: (identifier) @property)

(rhs_action
  name: ["insert" "insertLogical" "modify" "update" "retract" "delete"] @function.builtin)

(rhs_implicit
  ["drools" "kcontext" "entryPoints" "channels"] @variable.builtin)

(annotation
  name: (identifier) @attribute.annotation)

(line_comment) @comment
(block_comment) @comment
(string) @string
(number) @number
(boolean) @boolean

