;; queries/drools/folds.scm
;; Tree-sitter fold queries for Drools Rule Language

(rule_declaration) @fold
(declare_statement) @fold
(query_declaration) @fold
(function_declaration) @fold
(block_comment) @fold
