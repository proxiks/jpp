! ============================================================
! GJC PARSER - Written in Fortran 90
! J++ Programming Language Parser
! BSD-2-Clause License
! ============================================================

module gjc_parser
    use gjc_lexer
    use gjc_ast
    implicit none
    
    ! Precedence levels
    integer, parameter :: PREC_LOWEST     = 1
    integer, parameter :: PREC_ASSIGN     = 2
    integer, parameter :: PREC_OR         = 3
    integer, parameter :: PREC_AND        = 4
    integer, parameter :: PREC_EQUALS     = 5
    integer, parameter :: PREC_LESSGREATER = 6
    integer, parameter :: PREC_SLICE      = 7
    integer, parameter :: PREC_SUM        = 8
    integer, parameter :: PREC_PRODUCT    = 9
    integer, parameter :: PREC_PREFIX     = 10
    integer, parameter :: PREC_CALL       = 11
    integer, parameter :: PREC_INDEX      = 12
    integer, parameter :: PREC_POSTFIX    = 13
    
    ! Parser state
    type :: ParserState
        type(LexerState) :: lexer
        type(Token) :: cur_token
        type(Token) :: peek_token
        character(len=1024), allocatable :: errors(:)
        integer :: error_count
    end type ParserState
    
contains
    
    ! Initialize parser
    subroutine parser_init(ps, l)
        type(ParserState), intent(inout) :: ps
        type(LexerState), intent(inout) :: l
        
        ps%lexer = l
        ps%error_count = 0
        allocate(ps%errors(100))
        
        call parser_next_token(ps)
        call parser_next_token(ps)
    end subroutine parser_init
    
    ! Advance to next token
    subroutine parser_next_token(ps)
        type(ParserState), intent(inout) :: ps
        
        ps%cur_token = ps%peek_token
        ps%peek_token = lexer_next_token(ps%lexer)
    end subroutine parser_next_token
    
    ! Check current token
    function parser_cur_is(ps, tok_type) result(res)
        type(ParserState), intent(in) :: ps
        integer, intent(in) :: tok_type
        logical :: res
        
        res = (ps%cur_token%type == tok_type)
    end function parser_cur_is
    
    ! Check peek token
    function parser_peek_is(ps, tok_type) result(res)
        type(ParserState), intent(in) :: ps
        integer, intent(in) :: tok_type
        logical :: res
        
        res = (ps%peek_token%type == tok_type)
    end function parser_peek_is
    
    ! Expect peek token
    function parser_expect_peek(ps, tok_type) result(res)
        type(ParserState), intent(inout) :: ps
        integer, intent(in) :: tok_type
        logical :: res
        
        if (parser_peek_is(ps, tok_type)) then
            call parser_next_token(ps)
            res = .true.
        else
            call parser_peek_error(ps, tok_type)
            res = .false.
        end if
    end function parser_expect_peek
    
    ! Add error
    subroutine parser_add_error(ps, msg)
        type(ParserState), intent(inout) :: ps
        character(len=*), intent(in) :: msg
        
        ps%error_count = ps%error_count + 1
        if (ps%error_count <= 100) then
            ps%errors(ps%error_count) = msg
        end if
    end subroutine parser_add_error
    
    ! Peek error
    subroutine parser_peek_error(ps, tok_type)
        type(ParserState), intent(inout) :: ps
        integer, intent(in) :: tok_type
        character(len=256) :: msg
        
        write(msg, *) "Expected token type ", tok_type, ", got ", ps%peek_token%type
        call parser_add_error(ps, trim(msg))
    end subroutine parser_peek_error
    
    ! Get precedence
    function parser_peek_prec(ps) result(prec)
        type(ParserState), intent(in) :: ps
        integer :: prec
        
        select case (ps%peek_token%type)
        case (TOK_EQUAL)
            prec = PREC_ASSIGN
        case (TOK_OR)
            prec = PREC_OR
        case (TOK_AND)
            prec = PREC_AND
        case (TOK_EQ, TOK_NE)
            prec = PREC_EQUALS
        case (TOK_LT, TOK_GT, TOK_LE, TOK_GE)
            prec = PREC_LESSGREATER
        case (TOK_COLON)
            prec = PREC_SLICE
        case (TOK_PLUS, TOK_MINUS)
            prec = PREC_SUM
        case (TOK_STAR, TOK_DOTSTAR, TOK_DOTSLASH, TOK_CARET, TOK_BANG)
            prec = PREC_PRODUCT
        case (TOK_LPAREN)
            prec = PREC_CALL
        case (TOK_LBRACKET)
            prec = PREC_INDEX
        case (TOK_TILDE)
            prec = PREC_ASSIGN  ! Pipe
        case default
            prec = PREC_LOWEST
        end select
    end function parser_peek_prec
    
    ! Parse program
    function parse_program(ps) result(prog)
        type(ParserState), intent(inout) :: ps
        type(ProgramNode) :: prog
        
        allocate(prog%statements(0))
        
        do while (.not. parser_cur_is(ps, TOK_EOF))
            block
                type(StatementNode), pointer :: stmt
                stmt => parse_statement(ps)
                if (associated(stmt)) then
                    call program_add_statement(prog, stmt)
                end if
            end block
            call parser_next_token(ps)
        end do
    end function parse_program
    
    ! Parse statement
    function parse_statement(ps) result(stmt)
        type(ParserState), intent(inout) :: ps
        type(StatementNode), pointer :: stmt
        
        nullify(stmt)
        
        select case (ps%cur_token%type)
        case (TOK_INC)
            stmt => parse_include_stmt(ps)
        case (TOK_MAQ)
            stmt => parse_maq_stmt(ps)
        case (TOK_DEFINE)
            stmt => parse_define_stmt(ps)
        case (TOK_LET)
            stmt => parse_let_stmt(ps)
        case (TOK_RETURN)
            stmt => parse_return_stmt(ps)
        case (TOK_FN)
            stmt => parse_fn_stmt(ps)
        case (TOK_FORMULA)
            stmt => parse_formula_stmt(ps)
        case (TOK_NEWLINE)
            ! Skip
        case default
            stmt => parse_expr_stmt(ps)
        end select
    end function parse_statement
    
    ! #inc <module>
    function parse_include_stmt(ps) result(stmt)
        type(ParserState), intent(inout) :: ps
        type(StatementNode), pointer :: stmt
        type(IncludeStmtNode), pointer :: inc_stmt
        
        allocate(inc_stmt)
        inc_stmt%base%token = ps%cur_token
        
        if (.not. parser_expect_peek(ps, TOK_LT)) return
        
        call parser_next_token(ps)
        inc_stmt%module_name = ps%cur_token%literal
        
        if (.not. parser_expect_peek(ps, TOK_GT)) return
        
        stmt => inc_stmt
    end function parse_include_stmt
    
    ! #maq <domain>
    function parse_maq_stmt(ps) result(stmt)
        type(ParserState), intent(inout) :: ps
        type(StatementNode), pointer :: stmt
        type(MaqStmtNode), pointer :: maq_stmt
        
        allocate(maq_stmt)
        maq_stmt%base%token = ps%cur_token
        
        if (.not. parser_expect_peek(ps, TOK_LT)) return
        
        call parser_next_token(ps)
        maq_stmt%domain = ps%cur_token%literal
        
        if (.not. parser_expect_peek(ps, TOK_GT)) return
        
        stmt => maq_stmt
    end function parse_maq_stmt
    
    ! #define name
    function parse_define_stmt(ps) result(stmt)
        type(ParserState), intent(inout) :: ps
        type(StatementNode), pointer :: stmt
        type(DefineStmtNode), pointer :: def_stmt
        
        allocate(def_stmt)
        def_stmt%base%token = ps%cur_token
        
        call parser_next_token(ps)
        def_stmt%name = ps%cur_token%literal
        
        stmt => def_stmt
    end function parse_define_stmt
    
    ! let name = expr
    function parse_let_stmt(ps) result(stmt)
        type(ParserState), intent(inout) :: ps
        type(StatementNode), pointer :: stmt
        type(LetStmtNode), pointer :: let_stmt
        
        allocate(let_stmt)
        let_stmt%base%token = ps%cur_token
        
        if (.not. parser_expect_peek(ps, TOK_IDENT)) return
        
        let_stmt%name = ps%cur_token%literal
        
        if (.not. parser_expect_peek(ps, TOK_EQUAL)) return
        
        call parser_next_token(ps)
        let_stmt%value => parse_expression(ps, PREC_LOWEST)
        
        stmt => let_stmt
    end function parse_let_stmt
    
    ! return expr
    function parse_return_stmt(ps) result(stmt)
        type(ParserState), intent(inout) :: ps
        type(StatementNode), pointer :: stmt
        type(ReturnStmtNode), pointer :: ret_stmt
        
        allocate(ret_stmt)
        ret_stmt%base%token = ps%cur_token
        
        call parser_next_token(ps)
        ret_stmt%value => parse_expression(ps, PREC_LOWEST)
        
        stmt => ret_stmt
    end function parse_return_stmt
    
    ! fn name(params) { body }
    function parse_fn_stmt(ps) result(stmt)
        type(ParserState), intent(inout) :: ps
        type(StatementNode), pointer :: stmt
        type(FnStmtNode), pointer :: fn_stmt
        
        allocate(fn_stmt)
        fn_stmt%base%token = ps%cur_token
        
        if (.not. parser_expect_peek(ps, TOK_IDENT)) return
        fn_stmt%name = ps%cur_token%literal
        
        if (.not. parser_expect_peek(ps, TOK_LPAREN)) return
        
        ! Parse parameters
        fn_stmt%params => parse_params(ps)
        
        if (.not. parser_expect_peek(ps, TOK_LBRACE)) return
        
        fn_stmt%body => parse_block(ps)
        
        stmt => fn_stmt
    end function parse_fn_stmt
    
    ! formula *n = (plasma) { ... }
    function parse_formula_stmt(ps) result(stmt)
        type(ParserState), intent(inout) :: ps
        type(StatementNode), pointer :: stmt
        type(FormulaStmtNode), pointer :: formula_stmt
        
        allocate(formula_stmt)
        formula_stmt%base%token = ps%cur_token
        
        ! Optional *name
        if (parser_peek_is(ps, TOK_STAR)) then
            call parser_next_token(ps)  ! consume *
            call parser_next_token(ps)  ! get name
            formula_stmt%name = ps%cur_token%literal
        end if
        
        if (.not. parser_expect_peek(ps, TOK_EQUAL)) return
        
        call parser_next_token(ps)
        
        ! (plasma) target
        if (parser_cur_is(ps, TOK_LPAREN)) then
            call parser_next_token(ps)
            formula_stmt%target = ps%cur_token%literal
            if (.not. parser_expect_peek(ps, TOK_RPAREN)) return
        end if
        
        if (.not. parser_expect_peek(ps, TOK_LBRACE)) return
        
        formula_stmt%body => parse_block(ps)
        
        stmt => formula_stmt
    end function parse_formula_stmt
    
    ! Parse expression statement
    function parse_expr_stmt(ps) result(stmt)
        type(ParserState), intent(inout) :: ps
        type(StatementNode), pointer :: stmt
        type(ExprStmtNode), pointer :: expr_stmt
        
        allocate(expr_stmt)
        expr_stmt%base%token = ps%cur_token
        expr_stmt%expr => parse_expression(ps, PREC_LOWEST)
        
        stmt => expr_stmt
    end function parse_expr_stmt
    
    ! Parse expression
    function parse_expression(ps, precedence) result(expr)
        type(ParserState), intent(inout) :: ps
        integer, intent(in) :: precedence
        type(ExpressionNode), pointer :: expr
        
        type(ExpressionNode), pointer :: left_expr
        integer :: next_prec
        
        nullify(expr)
        
        ! Parse prefix
        select case (ps%cur_token%type)
        case (TOK_IDENT)
            left_expr => parse_identifier(ps)
        case (TOK_NUMBER)
            left_expr => parse_number(ps)
        case (TOK_STRING)
            left_expr => parse_string(ps)
        case (TOK_MINUS, TOK_BANG, TOK_DOLLAR, TOK_AT)
            left_expr => parse_prefix_expr(ps)
        case (TOK_LPAREN)
            left_expr => parse_grouped_expr(ps)
        case (TOK_LBRACKET)
            left_expr => parse_matrix_expr(ps)
        case (TOK_LBRACE)
            left_expr => parse_block_expr(ps)
        case (TOK_DATA)
            left_expr => parse_data_expr(ps)
        case (TOK_FLAGACTION)
            left_expr => parse_flagaction_expr(ps)
        case default
            call parser_add_error(ps, "No prefix parser for token")
            return
        end select
        
        ! Parse infix
        do while (.not. parser_peek_is(ps, TOK_SEMICOLON) .and. &
                  .not. parser_peek_is(ps, TOK_NEWLINE) .and. &
                  precedence < parser_peek_prec(ps))
            
            call parser_next_token(ps)
            
            select case (ps%cur_token%type)
            case (TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_CARET, TOK_BANG, &
                  TOK_DOTSTAR, TOK_DOTSLASH, TOK_DOTCARET, &
                  TOK_EQ, TOK_NE, TOK_LT, TOK_GT, TOK_LE, TOK_GE, &
                  TOK_AND, TOK_OR, TOK_EQUAL)
                left_expr => parse_infix_expr(ps, left_expr)
            case (TOK_LPAREN)
                left_expr => parse_call_expr(ps, left_expr)
            case (TOK_LBRACKET)
                left_expr => parse_index_expr(ps, left_expr)
            case (TOK_TILDE)
                left_expr => parse_pipe_expr(ps, left_expr)
            case default
                exit
            end select
        end do
        
        expr => left_expr
    end function parse_expression
    
    ! Parse identifier
    function parse_identifier(ps) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), pointer :: expr
        type(IdentExprNode), pointer :: ident
        
        allocate(ident)
        ident%base%token = ps%cur_token
        ident%value = ps%cur_token%literal
        
        expr => ident
    end function parse_identifier
    
    ! Parse number
    function parse_number(ps) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), pointer :: expr
        type(NumberExprNode), pointer :: num
        
        allocate(num)
        num%base%token = ps%cur_token
        read(ps%cur_token%literal, *) num%value
        
        expr => num
    end function parse_number
    
    ! Parse string
    function parse_string(ps) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), pointer :: expr
        type(StringExprNode), pointer :: str
        
        allocate(str)
        str%base%token = ps%cur_token
        str%value = ps%cur_token%literal
        
        expr => str
    end function parse_string
    
    ! Parse prefix: -x, !x, $x, @x
    function parse_prefix_expr(ps) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), pointer :: expr
        type(PrefixExprNode), pointer :: prefix
        
        allocate(prefix)
        prefix%base%token = ps%cur_token
        prefix%operator = ps%cur_token%literal
        
        call parser_next_token(ps)
        prefix%right => parse_expression(ps, PREC_PREFIX)
        
        expr => prefix
    end function parse_prefix_expr
    
    ! Parse infix: a + b, a * b, a ^ b
    function parse_infix_expr(ps, left) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), intent(in) :: left
        type(ExpressionNode), pointer :: expr
        type(InfixExprNode), pointer :: infix
        integer :: prec
        
        allocate(infix)
        infix%base%token = ps%cur_token
        infix%operator = ps%cur_token%literal
        infix%left => left
        
        prec = parser_peek_prec(ps)
        call parser_next_token(ps)
        infix%right => parse_expression(ps, prec)
        
        expr => infix
    end function parse_infix_expr
    
    ! Parse grouped: (expr)
    function parse_grouped_expr(ps) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), pointer :: expr
        
        call parser_next_token(ps)
        expr => parse_expression(ps, PREC_LOWEST)
        
        if (.not. parser_expect_peek(ps, TOK_RPAREN)) then
            nullify(expr)
        end if
    end function parse_grouped_expr
    
    ! Parse matrix: [1,2;3,4]
    function parse_matrix_expr(ps) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), pointer :: expr
        type(MatrixExprNode), pointer :: matrix
        integer :: row_count, col_count
        
        allocate(matrix)
        matrix%base%token = ps%cur_token
        row_count = 0
        
        do
            row_count = row_count + 1
            ! Parse row elements
            do
                call parser_next_token(ps)
                block
                    type(ExpressionNode), pointer :: elem
                    elem => parse_expression(ps, PREC_LOWEST)
                    call matrix_add_element(matrix, row_count, elem)
                end block
                
                if (parser_peek_is(ps, TOK_COMMA)) then
                    call parser_next_token(ps)
                else
                    exit
                end if
            end do
            
            if (parser_peek_is(ps, TOK_SEMICOLON)) then
                call parser_next_token(ps)
            else
                exit
            end if
        end do
        
        if (.not. parser_expect_peek(ps, TOK_RBRACKET)) then
            nullify(expr)
            return
        end if
        
        expr => matrix
    end function parse_matrix_expr
    
    ! Parse block: { ... }
    function parse_block(ps) result(block)
        type(ParserState), intent(inout) :: ps
        type(BlockNode), pointer :: block
        
        allocate(block)
        block%base%token = ps%cur_token
        
        call parser_next_token(ps)
        
        do while (.not. parser_cur_is(ps, TOK_RBRACE) .and. &
                  .not. parser_cur_is(ps, TOK_EOF))
            block
                type(StatementNode), pointer :: stmt
                stmt => parse_statement(ps)
                if (associated(stmt)) then
                    call block_add_statement(block, stmt)
                end if
            end block
            call parser_next_token(ps)
        end do
        
    end function parse_block
    
    ! Parse block expression
    function parse_block_expr(ps) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), pointer :: expr
        type(BlockExprNode), pointer :: block_expr
        
        allocate(block_expr)
        block_expr%base%token = ps%cur_token
        block_expr%block => parse_block(ps)
        
        expr => block_expr
    end function parse_block_expr
    
    ! Parse %data%
    function parse_data_expr(ps) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), pointer :: expr
        type(DataExprNode), pointer :: data_expr
        
        allocate(data_expr)
        data_expr%base%token = ps%cur_token
        data_expr%name = ps%cur_token%literal
        
        expr => data_expr
    end function parse_data_expr
    
    ! Parse *flagAction(MIX)
    function parse_flagaction_expr(ps) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), pointer :: expr
        type(FlagActionExprNode), pointer :: fa_expr
        
        allocate(fa_expr)
        fa_expr%base%token = ps%cur_token
        
        if (.not. parser_expect_peek(ps, TOK_LPAREN)) return
        
        call parser_next_token(ps)
        fa_expr%action = ps%cur_token%literal
        
        if (.not. parser_expect_peek(ps, TOK_RPAREN)) return
        
        expr => fa_expr
    end function parse_flagaction_expr
    
    ! Parse call: fn(args)
    function parse_call_expr(ps, function_expr) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), intent(in) :: function_expr
        type(ExpressionNode), pointer :: expr
        type(CallExprNode), pointer :: call
        
        allocate(call)
        call%base%token = ps%cur_token
        call%function => function_expr
        call%args => parse_args(ps)
        
        expr => call
    end function parse_call_expr
    
    ! Parse index: arr[i]
    function parse_index_expr(ps, left) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), intent(in) :: left
        type(ExpressionNode), pointer :: expr
        type(IndexExprNode), pointer :: idx
        
        allocate(idx)
        idx%base%token = ps%cur_token
        idx%left => left
        
        call parser_next_token(ps)
        idx%index => parse_expression(ps, PREC_LOWEST)
        
        if (.not. parser_expect_peek(ps, TOK_RBRACKET)) then
            nullify(expr)
            return
        end if
        
        expr => idx
    end function parse_index_expr
    
    ! Parse pipe: a ~ b
    function parse_pipe_expr(ps, left) result(expr)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), intent(in) :: left
        type(ExpressionNode), pointer :: expr
        type(PipeExprNode), pointer :: pipe
        
        allocate(pipe)
        pipe%base%token = ps%cur_token
        pipe%left => left
        
        call parser_next_token(ps)
        pipe%right => parse_expression(ps, PREC_ASSIGN)
        
        expr => pipe
    end function parse_pipe_expr
    
    ! Parse parameters
    function parse_params(ps) result(params)
        type(ParserState), intent(inout) :: ps
        type(ParamNode), pointer :: params(:)
        integer :: count
        
        allocate(params(0))
        count = 0
        
        if (parser_peek_is(ps, TOK_RPAREN)) then
            call parser_next_token(ps)
            return
        end if
        
        call parser_next_token(ps)
        count = count + 1
        call add_param(params, ps%cur_token%literal)
        
        do while (parser_peek_is(ps, TOK_COMMA))
            call parser_next_token(ps)
            call parser_next_token(ps)
            count = count + 1
            call add_param(params, ps%cur_token%literal)
        end do
        
        if (.not. parser_expect_peek(ps, TOK_RPAREN)) then
            deallocate(params)
            allocate(params(0))
        end if
    end function parse_params
    
    ! Parse arguments
    function parse_args(ps) result(args)
        type(ParserState), intent(inout) :: ps
        type(ExpressionNode), pointer :: args(:)
        
        allocate(args(0))
        
        if (parser_peek_is(ps, TOK_RPAREN)) then
            call parser_next_token(ps)
            return
        end if
        
        call parser_next_token(ps)
        call add_arg(args, parse_expression(ps, PREC_LOWEST))
        
        do while (parser_peek_is(ps, TOK_COMMA))
            call parser_next_token(ps)
            call parser_next_token(ps)
            call add_arg(args, parse_expression(ps, PREC_LOWEST))
        end do
        
        if (.not. parser_expect_peek(ps, TOK_RPAREN)) then
            deallocate(args)
            allocate(args(0))
        end if
    end function parse_args

end module gjc_parser