
module gjc_lexer
    implicit none
    
    ! Token types
    integer, parameter :: TOK_EOF        = 0
    integer, parameter :: TOK_NEWLINE    = 1
    integer, parameter :: TOK_IDENT      = 2
    integer, parameter :: TOK_NUMBER     = 3
    integer, parameter :: TOK_STRING     = 4
    
    ! Physics/Macro keywords
    integer, parameter :: TOK_INC        = 10
    integer, parameter :: TOK_MAQ        = 11
    integer, parameter :: TOK_DEFINE     = 12
    integer, parameter :: TOK_FORMULA    = 13
    integer, parameter :: TOK_PLASMA     = 14
    integer, parameter :: TOK_CALL       = 15
    integer, parameter :: TOK_DATA       = 16
    integer, parameter :: TOK_FLAGACTION = 17
    integer, parameter :: TOK_REACT      = 18
    integer, parameter :: TOK_ACTION     = 19
    integer, parameter :: TOK_MEASURE    = 20
    integer, parameter :: TOK_LOG        = 21
    
    ! Math/Physics types
    integer, parameter :: TOK_VEC2       = 30
    integer, parameter :: TOK_VEC3       = 31
    integer, parameter :: TOK_VEC4       = 32
    integer, parameter :: TOK_MAT2     = 33
    integer, parameter :: TOK_MAT3     = 34
    integer, parameter :: TOK_MAT4     = 35
    integer, parameter :: TOK_QUAT     = 36
    integer, parameter :: TOK_F64      = 37
    integer, parameter :: TOK_F32      = 38
    integer, parameter :: TOK_I32      = 39
    integer, parameter :: TOK_I64      = 40
    integer, parameter :: TOK_USIZE    = 41
    
    ! Operators
    integer, parameter :: TOK_STAR       = 50
    integer, parameter :: TOK_CARET      = 51
    integer, parameter :: TOK_BANG       = 52
    integer, parameter :: TOK_DOLLAR     = 53
    integer, parameter :: TOK_AT         = 54
    integer, parameter :: TOK_TILDE      = 55
    integer, parameter :: TOK_PERCENT    = 56
    integer, parameter :: TOK_EQUAL      = 57
    integer, parameter :: TOK_COLON      = 58
    integer, parameter :: TOK_SEMICOLON  = 59
    integer, parameter :: TOK_COMMA      = 60
    integer, parameter :: TOK_DOT        = 61
    integer, parameter :: TOK_DOTSTAR    = 62
    integer, parameter :: TOK_DOTSLASH   = 63
    integer, parameter :: TOK_DOTCARET   = 64
    integer, parameter :: TOK_BACKSLASH  = 65
    
    ! Brackets
    integer, parameter :: TOK_LPAREN     = 70
    integer, parameter :: TOK_RPAREN     = 71
    integer, parameter :: TOK_LBRACKET   = 72
    integer, parameter :: TOK_RBRACKET   = 73
    integer, parameter :: TOK_LBRACE     = 74
    integer, parameter :: TOK_RBRACE     = 75
    
    ! Math functions
    integer, parameter :: TOK_SIN        = 80
    integer, parameter :: TOK_COS        = 81
    integer, parameter :: TOK_TAN        = 82
    integer, parameter :: TOK_SQRT       = 83
    integer, parameter :: TOK_ABS        = 84
    integer, parameter :: TOK_EXP        = 85
    integer, parameter :: TOK_POW        = 86
    integer, parameter :: TOK_FFT        = 87
    integer, parameter :: TOK_IFFT       = 88
    integer, parameter :: TOK_EYE        = 89
    integer, parameter :: TOK_ZEROS      = 90
    integer, parameter :: TOK_ONES       = 91
    integer, parameter :: TOK_RAND       = 92
    integer, parameter :: TOK_LINSPACE   = 93
    
    ! ODE
    integer, parameter :: TOK_ODE45      = 100
    integer, parameter :: TOK_ODE23      = 101
    integer, parameter :: TOK_EULER      = 102
    
    ! Plotting
    integer, parameter :: TOK_PLOT       = 110
    integer, parameter :: TOK_HOLD       = 111
    integer, parameter :: TOK_LEGEND     = 112
    integer, parameter :: TOK_XLABEL     = 113
    integer, parameter :: TOK_YLABEL     = 114
    integer, parameter :: TOK_TITLE      = 115
    integer, parameter :: TOK_GRID       = 116
    integer, parameter :: TOK_SURF       = 117
    integer, parameter :: TOK_MESH       = 118
    integer, parameter :: TOK_CONTOUR    = 119
    integer, parameter :: TOK_AXIS       = 120
    integer, parameter :: TOK_DRAWNOW    = 121
    integer, parameter :: TOK_SAVEFIG    = 122
    
    ! Control flow
    integer, parameter :: TOK_FN         = 130
    integer, parameter :: TOK_LET        = 131
    integer, parameter :: TOK_IF         = 132
    integer, parameter :: TOK_ELSE       = 133
    integer, parameter :: TOK_FOR        = 134
    integer, parameter :: TOK_WHILE      = 135
    integer, parameter :: TOK_RETURN     = 136
    integer, parameter :: TOK_LOOP       = 137
    integer, parameter :: TOK_BREAK      = 138
    integer, parameter :: TOK_EXTERN     = 139
    integer, parameter :: TOK_ASM        = 140
    
    ! Comparison
    integer, parameter :: TOK_LT         = 150
    integer, parameter :: TOK_GT         = 151
    integer, parameter :: TOK_LE         = 152
    integer, parameter :: TOK_GE         = 153
    integer, parameter :: TOK_EQ         = 154
    integer, parameter :: TOK_NE         = 155
    integer, parameter :: TOK_AND        = 156
    integer, parameter :: TOK_OR         = 157
    
    ! Token structure
    type :: Token
        integer :: type
        character(len=256) :: literal
        integer :: line
        integer :: col
    end type Token
    
    ! Lexer state
    type :: LexerState
        character(len=:), allocatable :: input
        integer :: pos
        integer :: read_pos
        integer :: line
        integer :: col
        character :: ch
    end type LexerState
    
contains
    
    ! Initialize lexer
    subroutine lexer_init(l, input_str)
        type(LexerState), intent(inout) :: l
        character(len=*), intent(in) :: input_str
        
        l%input = input_str
        l%pos = 1
        l%read_pos = 1
        l%line = 1
        l%col = 0
        call lexer_read_char(l)
    end subroutine lexer_init
    
    ! Read next character
    subroutine lexer_read_char(l)
        type(LexerState), intent(inout) :: l
        
        if (l%read_pos > len(l%input)) then
            l%ch = char(0)
        else
            l%ch = l%input(l%read_pos:l%read_pos)
        end if
        
        l%pos = l%read_pos
        l%read_pos = l%read_pos + 1
        l%col = l%col + 1
        
        if (l%ch == char(10)) then
            l%line = l%line + 1
            l%col = 0
        end if
    end subroutine lexer_read_char
    
    ! Peek next character
    function lexer_peek_char(l) result(ch)
        type(LexerState), intent(in) :: l
        character :: ch
        
        if (l%read_pos > len(l%input)) then
            ch = char(0)
        else
            ch = l%input(l%read_pos:l%read_pos)
        end if
    end function lexer_peek_char
    
    ! Skip whitespace
    subroutine lexer_skip_whitespace(l)
        type(LexerState), intent(inout) :: l
        
        do while (l%ch == ' ' .or. l%ch == char(9) .or. l%ch == char(13))
            call lexer_read_char(l)
        end do
    end subroutine lexer_skip_whitespace
    
    ! Skip comments
    subroutine lexer_skip_comment(l)
        type(LexerState), intent(inout) :: l
        
        if (l%ch == '/' .and. lexer_peek_char(l) == '/') then
            do while (l%ch /= char(10) .and. ichar(l%ch) /= 0)
                call lexer_read_char(l)
            end do
        end if
    end subroutine lexer_skip_comment
    
    ! Check if letter
    function is_letter(ch) result(res)
        character, intent(in) :: ch
        logical :: res
        
        res = (ch >= 'a' .and. ch <= 'z') .or. &
              (ch >= 'A' .and. ch <= 'Z') .or. &
              (ch == '_')
    end function is_letter
    
    ! Check if digit
    function is_digit(ch) result(res)
        character, intent(in) :: ch
        logical :: res
        
        res = (ch >= '0' .and. ch <= '9')
    end function is_digit
    
    ! Read identifier
    function lexer_read_ident(l) result(ident)
        type(LexerState), intent(inout) :: l
        character(len=256) :: ident
        integer :: start, length
        
        start = l%pos
        length = 0
        
        do while (is_letter(l%ch) .or. is_digit(l%ch) .or. l%ch == '_')
            call lexer_read_char(l)
            length = length + 1
        end do
        
        ident = l%input(start:start+length-1)
    end function lexer_read_ident
    
    ! Read number
    function lexer_read_number(l) result(num_str)
        type(LexerState), intent(inout) :: l
        character(len=256) :: num_str
        integer :: start, length
        logical :: has_dot, has_exp
        
        start = l%pos
        length = 0
        has_dot = .false.
        has_exp = .false.
        
        do while (is_digit(l%ch) .or. l%ch == '.' .or. l%ch == 'e' .or. &
                  l%ch == 'E' .or. l%ch == '-' .or. l%ch == '+')
            
            if (l%ch == '.') then
                if (has_dot) exit
                has_dot = .true.
            end if
            
            if (l%ch == 'e' .or. l%ch == 'E') then
                if (has_exp) exit
                has_exp = .true.
            end if
            
            call lexer_read_char(l)
            length = length + 1
        end do
        
        num_str = l%input(start:start+length-1)
    end function lexer_read_number
    
    ! Read string
    function lexer_read_string(l, quote) result(str)
        type(LexerState), intent(inout) :: l
        character, intent(in) :: quote
        character(len=256) :: str
        integer :: start, length
        
        call lexer_read_char(l)  ! consume opening quote
        start = l%pos
        length = 0
        
        do while (l%ch /= quote .and. ichar(l%ch) /= 0)
            call lexer_read_char(l)
            length = length + 1
        end do
        
        str = l%input(start:start+length-1)
        
        if (l%ch == quote) then
            call lexer_read_char(l)  ! consume closing quote
        end if
    end function lexer_read_string
    
    ! Lookup keyword
    function lookup_keyword(ident) result(tok_type)
        character(len=*), intent(in) :: ident
        integer :: tok_type
        
        select case (trim(ident))
        case ('formula')
            tok_type = TOK_FORMULA
        case ('plasma')
            tok_type = TOK_PLASMA
        case ('react')
            tok_type = TOK_REACT
        case ('action')
            tok_type = TOK_ACTION
        case ('measure')
            tok_type = TOK_MEASURE
        case ('log')
            tok_type = TOK_LOG
        case ('vec2')
            tok_type = TOK_VEC2
        case ('vec3')
            tok_type = TOK_VEC3
        case ('vec4')
            tok_type = TOK_VEC4
        case ('mat2')
            tok_type = TOK_MAT2
        case ('mat3')
            tok_type = TOK_MAT3
        case ('mat4')
            tok_type = TOK_MAT4
        case ('quat')
            tok_type = TOK_QUAT
        case ('f64')
            tok_type = TOK_F64
        case ('f32')
            tok_type = TOK_F32
        case ('i32')
            tok_type = TOK_I32
        case ('i64')
            tok_type = TOK_I64
        case ('usize')
            tok_type = TOK_USIZE
        case ('sin')
            tok_type = TOK_SIN
        case ('cos')
            tok_type = TOK_COS
        case ('tan')
            tok_type = TOK_TAN
        case ('sqrt')
            tok_type = TOK_SQRT
        case ('abs')
            tok_type = TOK_ABS
        case ('exp')
            tok_type = TOK_EXP
        case ('pow')
            tok_type = TOK_POW
        case ('fft')
            tok_type = TOK_FFT
        case ('ifft')
            tok_type = TOK_IFFT
        case ('eye')
            tok_type = TOK_EYE
        case ('zeros')
            tok_type = TOK_ZEROS
        case ('ones')
            tok_type = TOK_ONES
        case ('rand')
            tok_type = TOK_RAND
        case ('linspace')
            tok_type = TOK_LINSPACE
        case ('ode45')
            tok_type = TOK_ODE45
        case ('ode23')
            tok_type = TOK_ODE23
        case ('euler')
            tok_type = TOK_EULER
        case ('plot')
            tok_type = TOK_PLOT
        case ('hold')
            tok_type = TOK_HOLD
        case ('legend')
            tok_type = TOK_LEGEND
        case ('xlabel')
            tok_type = TOK_XLABEL
        case ('ylabel')
            tok_type = TOK_YLABEL
        case ('title')
            tok_type = TOK_TITLE
        case ('grid')
            tok_type = TOK_GRID
        case ('surf')
            tok_type = TOK_SURF
        case ('mesh')
            tok_type = TOK_MESH
        case ('contour')
            tok_type = TOK_CONTOUR
        case ('axis')
            tok_type = TOK_AXIS
        case ('drawnow')
            tok_type = TOK_DRAWNOW
        case ('savefig')
            tok_type = TOK_SAVEFIG
        case ('fn')
            tok_type = TOK_FN
        case ('let')
            tok_type = TOK_LET
        case ('if')
            tok_type = TOK_IF
        case ('else')
            tok_type = TOK_ELSE
        case ('for')
            tok_type = TOK_FOR
        case ('while')
            tok_type = TOK_WHILE
        case ('return')
            tok_type = TOK_RETURN
        case ('loop')
            tok_type = TOK_LOOP
        case ('break')
            tok_type = TOK_BREAK
        case ('extern')
            tok_type = TOK_EXTERN
        case ('asm')
            tok_type = TOK_ASM
        case default
            tok_type = TOK_IDENT
        end select
    end function lookup_keyword
    
    ! Get next token
    function lexer_next_token(l) result(tok)
        type(LexerState), intent(inout) :: l
        type(Token) :: tok
        
        call lexer_skip_whitespace(l)
        call lexer_skip_comment(l)
        
        tok%line = l%line
        tok%col = l%col
        
        select case (l%ch)
        case (char(0))
            tok%type = TOK_EOF
            tok%literal = "EOF"
            
        case (char(10))
            tok%type = TOK_NEWLINE
            tok%literal = char(10)
            call lexer_read_char(l)
            
        case ('#')
            call lexer_read_char(l)
            if (l%ch == 'i' .and. lexer_peek_char(l) == 'n') then
                call lexer_read_char(l)
                call lexer_read_char(l)
                tok%type = TOK_INC
                tok%literal = "#inc"
            else if (l%ch == 'm' .and. lexer_peek_char(l) == 'a') then
                call lexer_read_char(l)
                call lexer_read_char(l)
                tok%type = TOK_MAQ
                tok%literal = "#maq"
            else if (l%ch == 'd') then
                call lexer_read_char(l)
                call lexer_read_char(l)
                call lexer_read_char(l)
                call lexer_read_char(l)
                call lexer_read_char(l)
                call lexer_read_char(l)
                tok%type = TOK_DEFINE
                tok%literal = "#define"
            else
                tok%type = TOK_IDENT
                tok%literal = "#" // fallback
            end if
            
        case ('%')
            call lexer_read_char(l)
            tok%type = TOK_DATA
            tok%literal = "%" // will be completed in parser
            
        case ('*')
            if (is_letter(lexer_peek_char(l))) then
                call lexer_read_char(l)
                tok%literal = lexer_read_ident(l)
                if (trim(tok%literal) == 'flagAction') then
                    tok%type = TOK_FLAGACTION
                    tok%literal = "*flagAction"
                else if (trim(tok%literal) == 'c') then
                    tok%type = TOK_STAR
                    tok%literal = "*c"
                else
                    tok%type = TOK_IDENT
                    tok%literal = "*" // fallback
                end if
            else
                tok%type = TOK_STAR
                tok%literal = "*"
                call lexer_read_char(l)
            end if
            
        case ('^')
            tok%type = TOK_CARET
            tok%literal = "^"
            call lexer_read_char(l)
            
        case ('!')
            if (lexer_peek_char(l) == '=') then
                call lexer_read_char(l)
                tok%type = TOK_NE
                tok%literal = "!="
            else
                tok%type = TOK_BANG
                tok%literal = "!"
            end if
            call lexer_read_char(l)
            
        case ('$')
            tok%type = TOK_DOLLAR
            tok%literal = "$"
            call lexer_read_char(l)
            
        case ('@')
            tok%type = TOK_AT
            tok%literal = "@"
            call lexer_read_char(l)
            
        case ('~')
            tok%type = TOK_TILDE
            tok%literal = "~"
            call lexer_read_char(l)
            
        case ('=')
            if (lexer_peek_char(l) == '=') then
                call lexer_read_char(l)
                tok%type = TOK_EQ
                tok%literal = "=="
            else
                tok%type = TOK_EQUAL
                tok%literal = "="
            end if
            call lexer_read_char(l)
            
        case (':')
            tok%type = TOK_COLON
            tok%literal = ":"
            call lexer_read_char(l)
            
        case (';')
            tok%type = TOK_SEMICOLON
            tok%literal = ";"
            call lexer_read_char(l)
            
        case (',')
            tok%type = TOK_COMMA
            tok%literal = ","
            call lexer_read_char(l)
            
        case ('.')
            if (lexer_peek_char(l) == '*') then
                call lexer_read_char(l)
                tok%type = TOK_DOTSTAR
                tok%literal = ".*"
                call lexer_read_char(l)
            else if (lexer_peek_char(l) == '/') then
                call lexer_read_char(l)
                tok%type = TOK_DOTSLASH
                tok%literal = "./"
                call lexer_read_char(l)
            else if (lexer_peek_char(l) == '^') then
                call lexer_read_char(l)
                tok%type = TOK_DOTCARET
                tok%literal = ".^"
                call lexer_read_char(l)
            else
                tok%type = TOK_DOT
                tok%literal = "."
                call lexer_read_char(l)
            end if
            
        case ('\')
            tok%type = TOK_BACKSLASH
            tok%literal = "\"
            call lexer_read_char(l)
            
        case ('<')
            if (lexer_peek_char(l) == '=') then
                call lexer_read_char(l)
                tok%type = TOK_LE
                tok%literal = "<="
            else
                tok%type = TOK_LT
                tok%literal = "<"
            end if
            call lexer_read_char(l)
            
        case ('>')
            if (lexer_peek_char(l) == '=') then
                call lexer_read_char(l)
                tok%type = TOK_GE
                tok%literal = ">="
            else
                tok%type = TOK_GT
                tok%literal = ">"
            end if
            call lexer_read_char(l)
            
        case ('&')
            if (lexer_peek_char(l) == '&') then
                call lexer_read_char(l)
                tok%type = TOK_AND
                tok%literal = "&&"
                call lexer_read_char(l)
            end if
            
        case ('|')
            if (lexer_peek_char(l) == '|') then
                call lexer_read_char(l)
                tok%type = TOK_OR
                tok%literal = "||"
                call lexer_read_char(l)
            end if
            
        case ('(')
            tok%type = TOK_LPAREN
            tok%literal = "("
            call lexer_read_char(l)
            
        case (')')
            tok%type = TOK_RPAREN
            tok%literal = ")"
            call lexer_read_char(l)
            
        case ('[')
            tok%type = TOK_LBRACKET
            tok%literal = "["
            call lexer_read_char(l)
            
        case (']')
            tok%type = TOK_RBRACKET
            tok%literal = "]"
            call lexer_read_char(l)
            
        case ('{')
            tok%type = TOK_LBRACE
            tok%literal = "{"
            call lexer_read_char(l)
            
        case ('}')
            tok%type = TOK_RBRACE
            tok%literal = "}"
            call lexer_read_char(l)
            
        case ('"', "'")
            tok%type = TOK_STRING
            tok%literal = lexer_read_string(l, l%ch)
            
        case default
            if (is_letter(l%ch)) then
                tok%literal = lexer_read_ident(l)
                tok%type = lookup_keyword(trim(tok%literal))
                
                ! Check for call_ prefix
                if (index(tok%literal, 'call_') == 1) then
                    tok%type = TOK_CALL
                end if
                
            else if (is_digit(l%ch)) then
                tok%type = TOK_NUMBER
                tok%literal = lexer_read_number(l)
                
            else
                tok%type = TOK_IDENT
                tok%literal = l%ch
                call lexer_read_char(l)
            end if
            
        end select
    end function lexer_next_token

end module gjc_lexer
