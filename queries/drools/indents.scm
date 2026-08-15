;; queries/drools/indents.scm
;; Tree-sitter indent queries for Drools Rule Language

(rule_declaration) @indent.begin
(declare_statement) @indent.begin
(query_declaration) @indent.begin
(function_declaration) @indent.begin

"end" @indent.end
"when" @indent.branch
"then" @indent.branch
