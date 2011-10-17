" Vim syntax file
" Language:	Lupa

if !exists("main_syntax")
  if version < 600
    syntax clear
  elseif exists("b:current_syntax")
    finish
  endif
  let main_syntax = 'lupa'
endif


syn keyword lupaCommentTodo    TODO FIXME XXX TBD contained
syn match   lupaLineComment    "\/\/.*" contains=@Spell,lupaCommentTodo
syn match   lupaCommentSkip    "^[ \t]*\*\($\|[ \t]\+\)"
syn region  lupaComment	       start="/\*"  end="\*/" contains=@Spell,lupaCommentTodo
syn match   lupaSpecial	       "\\\d\d\d\|\\."
"syn match   lupaOperator       "[,;.\-+=*|/\^]"
syn region  lupaStringD	       start=+"+  skip=+\\\\\|\\"+  end=+"\|$+	contains=lupaSpecialCharacter
syn region  lupaStringS	       start=+'+  skip=+\\\\\|\\'+  end=+'\|$+	contains=lupaSpecialCharacter
syn region lupaStringD         start=+[uU]\=\z('''\|"""\)+ end="\z1" keepend contains=lupaSpecialCharacter

syn match   lupaComment "\%^#!.*"

syn match   lupaSpecialCharacter "'\\.'"
syn match   lupaNumber	       "-\=\<\(\d\|_\)\+L\=\>\|0[xX][0-9a-fA-F]\+\>"
syn region  lupaRegexpString     start=+/[^/*]+me=e-1 skip=+\\\\\|\\/+ end=+/+me=e-1

syn keyword lupaConditional	if else switch
syn keyword lupaRepeat		while for
syn keyword lupaBranch		break continue
syn keyword lupaOperator	in is typeof like
syn keyword lupaType		Array Boolean Date Function Number Object String RegExp int8 int16 int32 int64 uint8 uint16 uint32 uint64
syn keyword lupaStatement	return with
syn keyword lupaSpecial	        return with new bless isa does can gen __init __index __newindex __setitem __getitem __match __add __sub __mul __unm __pow __mod __call __missing __tostring __eq __le __lt __ge __gt __concat __each __make __size __len __gc __mode
syn keyword lupaBoolean		true false nil
syn keyword lupaNull		null undefined
syn keyword lupaIdentifier	var self
syn keyword lupaLabel		case default
syn keyword lupaException	try catch finally throw
syn keyword lupaGlobal		window top parent
syn keyword lupaMember		document event location
syn keyword lupaDeprecated	escape unescape
syn keyword lupaReserved	boolean byte char class grammar double enum export extends final float import int long native package short super transient trait object from as guard load yield
syn keyword lupaFunction	rule function method has needs

if exists("lupa_fold")
    syn match	lupaFunction	"\<function\>"
    syn region	lupaFunctionFold	start="\<function\>.*[^};]$" end="^\z1}.*$" transparent fold keepend

    syn sync match lupaSync	grouphere lupaFunctionFold "\<function\>"
    syn sync match lupaSync	grouphere NONE "^}"

    setlocal foldmethod=syntax
    setlocal foldtext=getline(v:foldstart)
else
    syn keyword lupaFunction	function method rule has
    syn match	lupaBraces	   "[{}\[\]]"
    syn match	lupaParens	   "[()]"
endif

syn sync fromstart
syn sync maxlines=100

if main_syntax == "lupa"
  syn sync ccomment lupaComment
endif

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_lupa_syn_inits")
  if version < 508
    let did_lupa_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif
  HiLink lupaComment		    Comment
  HiLink lupaLineComment	    Comment
  HiLink lupaCommentTodo	    Todo
  HiLink lupaSpecial		    Special
  HiLink lupaStringS		    String
  HiLink lupaStringD		    String
  HiLink lupaCharacter		    Character
  HiLink lupaSpecialCharacter	    lupaSpecial
  HiLink lupaNumber		    Number
  HiLink lupaConditional	    Conditional
  HiLink lupaRepeat		    Repeat
  HiLink lupaBranch		    Conditional
  HiLink lupaOperator		    Operator
  HiLink lupaType		    Type
  HiLink lupaStatement		    Statement
  HiLink lupaFunction		    Function
  HiLink lupaBraces		    Function
  HiLink lupaError		    Error
  HiLink lupaParenError		    lupaError
  HiLink lupaNull		    Keyword
  HiLink lupaBoolean		    Boolean
  HiLink lupaRegexpString	    String

  HiLink lupaIdentifier		    Identifier
  HiLink lupaLabel		    Label
  HiLink lupaException		    Exception
  HiLink lupaGlobal		    Keyword
  HiLink lupaMember		    Keyword
  HiLink lupaDeprecated		    Exception 
  HiLink lupaReserved		    Keyword
  HiLink lupaDebug		    Debug
  HiLink lupaConstant		    Label

  delcommand HiLink
endif

let b:current_syntax = "lupa"
if main_syntax == 'lupa'
  unlet main_syntax
endif

" vim: ts=8
