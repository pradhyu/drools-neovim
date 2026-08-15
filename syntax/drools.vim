" Vim syntax file
" Language:    Drools Rule Language (.drl, .dsl)
" Maintainer:  drools.nvim contributors

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Comments
syn region  droolsCommentLine   start="//" end="$" contains=@Spell
syn region  droolsCommentBlock  start="/\*" end="\*/" contains=@Spell

" Top-level Directives & Structure Keywords
syn keyword droolsStructure     package import global declare query function rule end
syn keyword droolsSection       when then

" Rule Attributes
syn keyword droolsAttribute     salience agenda-group ruleflow-group activation-group
syn keyword droolsAttribute     lock-on-active no-loop auto-focus enabled dialect
syn keyword droolsAttribute     duration timer calendars date-effective date-expires

" LHS Conditional & Pattern Keywords
syn keyword droolsConditional   and or not exists forall eval from over
syn keyword droolsConditional   accumulate collect entry-point
syn keyword droolsOperator      matches memberOf soundslike in excludes
syn match   droolsOperator      "\<contains\>"

" Built-in Constants & Literals
syn keyword droolsBoolean       true false
syn keyword droolsConstant      null

" Variables (Bound variables start with $)
syn match   droolsVariable      "\$[a-zA-Z_][a-zA-Z0-9_]*"

" Numbers
syn match   droolsNumber        "\<\d\+\>"
syn match   droolsNumber        "\<\d\+\.\d*\>"
syn match   droolsNumber        "0x[0-9a-fA-F]\+"

" Strings
syn region  droolsString        start='"' skip='\\"' end='"' contains=@Spell
syn region  droolsString        start="'" skip="\\'" end="'" contains=@Spell

" Type Declarations (@annotation)
syn match   droolsAnnotation    "@[a-zA-Z_][a-zA-Z0-9_]*"

" RHS Block Java highlighting
syn keyword droolsRHSKeyword    insert insertLogical modify update retract delete
syn keyword droolsRHSKeyword    drools kcontext system

" Highlight links
hi def link droolsCommentLine   Comment
hi def link droolsCommentBlock  Comment
hi def link droolsStructure     Keyword
hi def link droolsSection       Statement
hi def link droolsAttribute     PreProc
hi def link droolsConditional   Conditional
hi def link droolsOperator      Operator
hi def link droolsBoolean       Boolean
hi def link droolsConstant      Constant
hi def link droolsVariable      Identifier
hi def link droolsNumber        Number
hi def link droolsString        String
hi def link droolsAnnotation    Special
hi def link droolsRHSKeyword    Function

let b:current_syntax = "drools"

let &cpo = s:cpo_save
unlet s:cpo_save
