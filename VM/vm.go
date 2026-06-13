package jpp

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

const (
	VMStackSize  = 1024 * 1024  // 1MB stack
	VMHeapSize   = 16 * 1024 * 1024 // 16MB heap
	VMNumRegs    = 16
	VMMaxCallDepth = 1024
)

// VM Register
type VMReg uint64

// VM Value types
type VMValueType int

const (
	VMVoid VMValueType = iota
	VMInt
	VMFloat
	VMString
	VMBool
	VMChar
	VMPtr
	VMArray
	VMStruct
)

type VMValue struct {
	Type  VMValueType
	Int   int64
	Float float64
	Str   string
	Bool  bool
	Char  rune
	Ptr   uint64
	Array []VMValue
	Struct map[string]VMValue
}

func (v VMValue) String() string {
	switch v.Type {
	case VMInt:
		return strconv.FormatInt(v.Int, 10)
	case VMFloat:
		return strconv.FormatFloat(v.Float, 'f', -1, 64)
	case VMString:
		return v.Str
	case VMBool:
		if v.Bool {
			return "true"
		}
		return "false"
	case VMChar:
		return string(v.Char)
	case VMPtr:
		return fmt.Sprintf("0x%X", v.Ptr)
	case VMArray:
		return fmt.Sprintf("array[%d]", len(v.Array))
	case VMStruct:
		return fmt.Sprintf("struct{%d}", len(v.Struct))
	default:
		return "null"
	}
}

func (v VMValue) ToInt() int64 {
	switch v.Type {
	case VMInt:
		return v.Int
	case VMFloat:
		return int64(v.Float)
	case VMBool:
		if v.Bool {
			return 1
		}
		return 0
	case VMChar:
		return int64(v.Char)
	default:
		return 0
	}
}

func (v VMValue) ToFloat() float64 {
	switch v.Type {
	case VMInt:
		return float64(v.Int)
	case VMFloat:
		return v.Float
	default:
		return 0
	}
}

func (v VMValue) ToBool() bool {
	switch v.Type {
	case VMInt:
		return v.Int != 0
	case VMFloat:
		return v.Float != 0
	case VMBool:
		return v.Bool
	case VMString:
		return len(v.Str) > 0
	default:
		return false
	}
}

// ============================================================================
// VM INSTRUCTIONS
// ============================================================================

type VMOpCode byte

const (
	// Stack operations
	OP_NOP VMOpCode = iota
	OP_PUSH
	OP_POP
	OP_DUP
	OP_SWAP

	// Register operations
	OP_LOAD
	OP_STORE
	OP_LOADI
	OP_LOADF
	OP_LOADS
	OP_LOADB
	OP_LOADC

	// Arithmetic
	OP_ADD
	OP_SUB
	OP_MUL
	OP_DIV
	OP_MOD
	OP_NEG
	OP_INC
	OP_DEC

	// Bitwise
	OP_AND
	OP_OR
	OP_XOR
	OP_NOT
	OP_SHL
	OP_SHR

	// Comparison
	OP_EQ
	OP_NE
	OP_LT
	OP_GT
	OP_LE
	OP_GE

	// Logical
	OP_LAND
	OP_LOR
	OP_LNOT

	// Control flow
	OP_JMP
	OP_JZ
	OP_JNZ
	OP_CALL
	OP_RET
	OP_SYSCALL

	// Memory
	OP_LOAD_MEM
	OP_STORE_MEM
	OP_ALLOC
	OP_FREE
	OP_GET_FIELD
	OP_SET_FIELD
	OP_GET_INDEX
	OP_SET_INDEX

	// Type conversion
	OP_I2F
	OP_F2I
	OP_I2S
	OP_S2I

	// Built-in functions
	OP_PRINT
	OP_SCAN
	OP_TIMER
	OP_RAND
	OP_TIME
	OP_EXIT
)

type VMInstruction struct {
	Op     VMOpCode
	Arg1   uint64
	Arg2   uint64
	Arg3   uint64
	Label  string
	Line   int
	Column int
}

func (i VMInstruction) String() string {
	opNames := []string{
		"NOP", "PUSH", "POP", "DUP", "SWAP",
		"LOAD", "STORE", "LOADI", "LOADF", "LOADS", "LOADB", "LOADC",
		"ADD", "SUB", "MUL", "DIV", "MOD", "NEG", "INC", "DEC",
		"AND", "OR", "XOR", "NOT", "SHL", "SHR",
		"EQ", "NE", "LT", "GT", "LE", "GE",
		"LAND", "LOR", "LNOT",
		"JMP", "JZ", "JNZ", "CALL", "RET", "SYSCALL",
		"LOAD_MEM", "STORE_MEM", "ALLOC", "FREE", "GET_FIELD", "SET_FIELD", "GET_INDEX", "SET_INDEX",
		"I2F", "F2I", "I2S", "S2I",
		"PRINT", "SCAN", "TIMER", "RAND", "TIME", "EXIT",
	}
	if int(i.Op) < len(opNames) {
		return fmt.Sprintf("%s %d %d %d", opNames[i.Op], i.Arg1, i.Arg2, i.Arg3)
	}
	return fmt.Sprintf("UNKNOWN %d", i.Op)
}

// ============================================================================
// VM CALL FRAME
// ============================================================================

type VMFrame struct {
	ReturnAddr uint64
	BasePtr    uint64
	Regs       [VMNumRegs]VMValue
	Locals     map[string]VMValue
}

// ============================================================================
// VIRTUAL MACHINE
// ============================================================================

type VM struct {
	// Registers
	Regs [VMNumRegs]VMValue
	RIP  uint64 // Instruction pointer
	RSP  uint64 // Stack pointer
	RBP  uint64 // Base pointer

	// Memory
	Stack  []VMValue
	Heap   []byte
	Code   []VMInstruction
	Labels map[string]uint64

	// Call stack
	Frames    []VMFrame
	FramePtr  int

	// State
	Running   bool
	ExitCode  int
	Output    strings.Builder
	Input     string
	InputPos  int

	// Built-in functions
	Builtins map[string]func(*VM, []VMValue) VMValue

	// Timer
	StartTime int64
}

func NewVM() *VM {
	vm := &VM{
		Stack:   make([]VMValue, VMStackSize),
		Heap:    make([]byte, VMHeapSize),
		Code:    make([]VMInstruction, 0),
		Labels:  make(map[string]uint64),
		Frames:  make([]VMFrame, VMMaxCallDepth),
		Builtins: make(map[string]func(*VM, []VMValue) VMValue),
		Running: false,
		ExitCode: 0,
	}
	vm.initBuiltins()
	return vm
}

func (vm *VM) initBuiltins() {
	vm.Builtins["printel"] = vm.builtinPrintel
	vm.Builtins["scanel"] = vm.builtinScanel
	vm.Builtins["timer"] = vm.builtinTimer
	vm.Builtins["rand"] = vm.builtinRand
	vm.Builtins["time"] = vm.builtinTime
	vm.Builtins["exit"] = vm.builtinExit
	vm.Builtins["len"] = vm.builtinLen
	vm.Builtins["typeof"] = vm.builtinTypeof
	vm.Builtins["sqrt"] = vm.builtinSqrt
	vm.Builtins["pow"] = vm.builtinPow
	vm.Builtins["sin"] = vm.builtinSin
	vm.Builtins["cos"] = vm.builtinCos
	vm.Builtins["tan"] = vm.builtinTan
	vm.Builtins["log"] = vm.builtinLog
	vm.Builtins["abs"] = vm.builtinAbs
	vm.Builtins["min"] = vm.builtinMin
	vm.Builtins["max"] = vm.builtinMax
	vm.Builtins["str"] = vm.builtinStr
	vm.Builtins["int"] = vm.builtinInt
	vm.Builtins["float"] = vm.builtinFloat
}

// ============================================================================
// STACK OPERATIONS
// ============================================================================

func (vm *VM) push(v VMValue) {
	if vm.RSP >= uint64(len(vm.Stack)) {
		panic("Stack overflow")
	}
	vm.Stack[vm.RSP] = v
	vm.RSP++
}

func (vm *VM) pop() VMValue {
	if vm.RSP == 0 {
		panic("Stack underflow")
	}
	vm.RSP--
	return vm.Stack[vm.RSP]
}

func (vm *VM) peek() VMValue {
	if vm.RSP == 0 {
		panic("Stack empty")
	}
	return vm.Stack[vm.RSP-1]
}

func (vm *VM) dup() {
	vm.push(vm.peek())
}

func (vm *VM) swap() {
	if vm.RSP < 2 {
		panic("Stack underflow")
	}
	vm.Stack[vm.RSP-1], vm.Stack[vm.RSP-2] = vm.Stack[vm.RSP-2], vm.Stack[vm.RSP-1]
}

// ============================================================================
// BUILT-IN FUNCTIONS
// ============================================================================

func (vm *VM) builtinPrintel(v *VM, args []VMValue) VMValue {
	format := ""
	if len(args) > 0 && args[0].Type == VMString {
		format = args[0].Str
	}
	
	argIdx := 1
	result := ""
	for i := 0; i < len(format); i++ {
		if format[i] == '%' && i+1 < len(format) {
			switch format[i+1] {
			case 'd', 'i':
				if argIdx < len(args) {
					result += args[argIdx].String()
					argIdx++
				}
				i++
			case 'f':
				if argIdx < len(args) {
					result += fmt.Sprintf("%.6f", args[argIdx].ToFloat())
					argIdx++
				}
				i++
			case 's':
				if argIdx < len(args) {
					result += args[argIdx].Str
					argIdx++
				}
				i++
			case 'c':
				if argIdx < len(args) {
					result += string(args[argIdx].Char)
					argIdx++
				}
				i++
			case 'x':
				if argIdx < len(args) {
					result += fmt.Sprintf("%X", args[argIdx].ToInt())
					argIdx++
				}
				i++
			case 'p':
				if argIdx < len(args) {
					result += fmt.Sprintf("0x%X", args[argIdx].Ptr)
					argIdx++
				}
				i++
			case '%':
				result += "%"
				i++
			default:
				result += string(format[i])
			}
		} else if format[i] == '\\' && i+1 < len(format) {
			switch format[i+1] {
			case 'n':
				result += "\n"
				i++
			case 't':
				result += "\t"
				i++
			case 'r':
				result += "\r"
				i++
			default:
				result += string(format[i])
			}
		} else {
			result += string(format[i])
		}
	}
	
	vm.Output.WriteString(result)
	fmt.Print(result)
	return VMValue{Type: VMInt, Int: int64(len(result))}
}

func (vm *VM) builtinScanel(v *VM, args []VMValue) VMValue {
	// Read from input buffer
	if vm.InputPos >= len(vm.Input) {
		return VMValue{Type: VMInt, Int: 0}
	}
	
	format := ""
	if len(args) > 0 && args[0].Type == VMString {
		format = args[0].Str
	}
	
	// Simple scanf implementation
	if strings.Contains(format, "%d") {
		// Read integer
		end := vm.InputPos
		for end < len(vm.Input) && (vm.Input[end] >= '0' && vm.Input[end] <= '9' || vm.Input[end] == '-') {
			end++
		}
		numStr := vm.Input[vm.InputPos:end]
		vm.InputPos = end
		num, _ := strconv.ParseInt(numStr, 10, 64)
		return VMValue{Type: VMInt, Int: num}
	}
	
	if strings.Contains(format, "%s") {
		// Read string
		end := vm.InputPos
		for end < len(vm.Input) && vm.Input[end] != ' ' && vm.Input[end] != '\n' {
			end++
		}
		str := vm.Input[vm.InputPos:end]
		vm.InputPos = end
		return VMValue{Type: VMString, Str: str}
	}
	
	return VMValue{Type: VMInt, Int: 0}
}

func (vm *VM) builtinTimer(v *VM, args []VMValue) VMValue {
	// Return current time in milliseconds
	return VMValue{Type: VMInt, Int: 0} // TODO: implement
}

func (vm *VM) builtinRand(v *VM, args []VMValue) VMValue {
	return VMValue{Type: VMInt, Int: 42} // TODO: proper random
}

func (vm *VM) builtinTime(v *VM, args []VMValue) VMValue {
	return VMValue{Type: VMInt, Int: 0} // TODO: implement
}

func (vm *VM) builtinExit(v *VM, args []VMValue) VMValue {
	code := 0
	if len(args) > 0 {
		code = int(args[0].ToInt())
	}
	vm.ExitCode = code
	vm.Running = false
	return VMValue{Type: VMVoid}
}

func (vm *VM) builtinLen(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMInt, Int: 0}
	}
	arg := args[0]
	switch arg.Type {
	case VMString:
		return VMValue{Type: VMInt, Int: int64(len(arg.Str))}
	case VMArray:
		return VMValue{Type: VMInt, Int: int64(len(arg.Array))}
	case VMStruct:
		return VMValue{Type: VMInt, Int: int64(len(arg.Struct))}
	default:
		return VMValue{Type: VMInt, Int: 0}
	}
}

func (vm *VM) builtinTypeof(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMString, Str: "void"}
	}
	
	typeNames := map[VMValueType]string{
		VMVoid: "void", VMInt: "int", VMFloat: "float",
		VMString: "string", VMBool: "bool", VMChar: "char",
		VMPtr: "pointer", VMArray: "array", VMStruct: "struct",
	}
	
	name := typeNames[args[0].Type]
	if name == "" {
		name = "unknown"
	}
	return VMValue{Type: VMString, Str: name}
}

func (vm *VM) builtinSqrt(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMFloat, Float: 0}
	}
	return VMValue{Type: VMFloat, Float: math.Sqrt(args[0].ToFloat())}
}

func (vm *VM) builtinPow(v *VM, args []VMValue) VMValue {
	if len(args) < 2 {
		return VMValue{Type: VMFloat, Float: 0}
	}
	return VMValue{Type: VMFloat, Float: math.Pow(args[0].ToFloat(), args[1].ToFloat())}
}

func (vm *VM) builtinSin(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMFloat, Float: 0}
	}
	return VMValue{Type: VMFloat, Float: math.Sin(args[0].ToFloat())}
}

func (vm *VM) builtinCos(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMFloat, Float: 0}
	}
	return VMValue{Type: VMFloat, Float: math.Cos(args[0].ToFloat())}
}

func (vm *VM) builtinTan(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMFloat, Float: 0}
	}
	return VMValue{Type: VMFloat, Float: math.Tan(args[0].ToFloat())}
}

func (vm *VM) builtinLog(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMFloat, Float: 0}
	}
	return VMValue{Type: VMFloat, Float: math.Log(args[0].ToFloat())}
}

func (vm *VM) builtinAbs(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMInt, Int: 0}
	}
	if args[0].Type == VMFloat {
		return VMValue{Type: VMFloat, Float: math.Abs(args[0].Float)}
	}
	val := args[0].ToInt()
	if val < 0 {
		val = -val
	}
	return VMValue{Type: VMInt, Int: val}
}

func (vm *VM) builtinMin(v *VM, args []VMValue) VMValue {
	if len(args) < 2 {
		return VMValue{Type: VMInt, Int: 0}
	}
	if args[0].Type == VMFloat || args[1].Type == VMFloat {
		return VMValue{Type: VMFloat, Float: math.Min(args[0].ToFloat(), args[1].ToFloat())}
	}
	if args[0].ToInt() < args[1].ToInt() {
		return args[0]
	}
	return args[1]
}

func (vm *VM) builtinMax(v *VM, args []VMValue) VMValue {
	if len(args) < 2 {
		return VMValue{Type: VMInt, Int: 0}
	}
	if args[0].Type == VMFloat || args[1].Type == VMFloat {
		return VMValue{Type: VMFloat, Float: math.Max(args[0].ToFloat(), args[1].ToFloat())}
	}
	if args[0].ToInt() > args[1].ToInt() {
		return args[0]
	}
	return args[1]
}

func (vm *VM) builtinStr(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMString, Str: ""}
	}
	return VMValue{Type: VMString, Str: args[0].String()}
}

func (vm *VM) builtinInt(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMInt, Int: 0}
	}
	return VMValue{Type: VMInt, Int: args[0].ToInt()}
}

func (vm *VM) builtinFloat(v *VM, args []VMValue) VMValue {
	if len(args) == 0 {
		return VMValue{Type: VMFloat, Float: 0}
	}
	return VMValue{Type: VMFloat, Float: args[0].ToFloat()}
}

// ============================================================================
// VM EXECUTION
// ============================================================================

func (vm *VM) Load(code []VMInstruction) {
	vm.Code = code
	vm.RIP = 0
	vm.RSP = 0
	vm.RBP = 0
	vm.FramePtr = 0
	vm.Running = false
	vm.ExitCode = 0
	vm.Output.Reset()
}

func (vm *VM) Execute() int {
	vm.Running = true
	
	for vm.Running && vm.RIP < uint64(len(vm.Code)) {
		inst := vm.Code[vm.RIP]
		vm.RIP++
		vm.executeInstruction(inst)
	}
	
	return vm.ExitCode
}

func (vm *VM) executeInstruction(inst VMInstruction) {
	switch inst.Op {
	case OP_NOP:
		// Do nothing

	case OP_PUSH:
		vm.push(VMValue{Type: VMInt, Int: int64(inst.Arg1)})

	case OP_POP:
		vm.pop()

	case OP_DUP:
		vm.dup()

	case OP_SWAP:
		vm.swap()

	case OP_LOAD:
		vm.push(vm.Regs[inst.Arg1])

	case OP_STORE:
		vm.Regs[inst.Arg1] = vm.pop()

	case OP_LOADI:
		vm.push(VMValue{Type: VMInt, Int: int64(inst.Arg1)})

	case OP_LOADF:
		vm.push(VMValue{Type: VMFloat, Float: math.Float64frombits(inst.Arg1)})

	case OP_LOADS:
		// String loaded from heap
		vm.push(VMValue{Type: VMString, Str: string(vm.Heap[inst.Arg1:inst.Arg1+inst.Arg2])})

	case OP_LOADB:
		vm.push(VMValue{Type: VMBool, Bool: inst.Arg1 != 0})

	case OP_LOADC:
		vm.push(VMValue{Type: VMChar, Char: rune(inst.Arg1)})

	case OP_ADD:
		b := vm.pop()
		a := vm.pop()
		if a.Type == VMFloat || b.Type == VMFloat {
			vm.push(VMValue{Type: VMFloat, Float: a.ToFloat() + b.ToFloat()})
		} else {
			vm.push(VMValue{Type: VMInt, Int: a.ToInt() + b.ToInt()})
		}

	case OP_SUB:
		b := vm.pop()
		a := vm.pop()
		if a.Type == VMFloat || b.Type == VMFloat {
			vm.push(VMValue{Type: VMFloat, Float: a.ToFloat() - b.ToFloat()})
		} else {
			vm.push(VMValue{Type: VMInt, Int: a.ToInt() - b.ToInt()})
		}

	case OP_MUL:
		b := vm.pop()
		a := vm.pop()
		if a.Type == VMFloat || b.Type == VMFloat {
			vm.push(VMValue{Type: VMFloat, Float: a.ToFloat() * b.ToFloat()})
		} else {
			vm.push(VMValue{Type: VMInt, Int: a.ToInt() * b.ToInt()})
		}

	case OP_DIV:
		b := vm.pop()
		a := vm.pop()
		if b.ToFloat() == 0 {
			panic("Division by zero")
		}
		if a.Type == VMFloat || b.Type == VMFloat {
			vm.push(VMValue{Type: VMFloat, Float: a.ToFloat() / b.ToFloat()})
		} else {
			vm.push(VMValue{Type: VMInt, Int: a.ToInt() / b.ToInt()})
		}

	case OP_MOD:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMInt, Int: a.ToInt() % b.ToInt()})

	case OP_NEG:
		a := vm.pop()
		if a.Type == VMFloat {
			vm.push(VMValue{Type: VMFloat, Float: -a.Float})
		} else {
			vm.push(VMValue{Type: VMInt, Int: -a.ToInt()})
		}

	case OP_INC:
		a := vm.pop()
		vm.push(VMValue{Type: VMInt, Int: a.ToInt() + 1})

	case OP_DEC:
		a := vm.pop()
		vm.push(VMValue{Type: VMInt, Int: a.ToInt() - 1})

	case OP_AND:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMInt, Int: a.ToInt() & b.ToInt()})

	case OP_OR:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMInt, Int: a.ToInt() | b.ToInt()})

	case OP_XOR:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMInt, Int: a.ToInt() ^ b.ToInt()})

	case OP_NOT:
		a := vm.pop()
		vm.push(VMValue{Type: VMInt, Int: ^a.ToInt()})

	case OP_SHL:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMInt, Int: a.ToInt() << uint(b.ToInt())})

	case OP_SHR:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMInt, Int: a.ToInt() >> uint(b.ToInt())})

	case OP_EQ:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMBool, Bool: a.ToInt() == b.ToInt()})

	case OP_NE:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMBool, Bool: a.ToInt() != b.ToInt()})

	case OP_LT:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMBool, Bool: a.ToInt() < b.ToInt()})

	case OP_GT:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMBool, Bool: a.ToInt() > b.ToInt()})

	case OP_LE:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMBool, Bool: a.ToInt() <= b.ToInt()})

	case OP_GE:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMBool, Bool: a.ToInt() >= b.ToInt()})

	case OP_LAND:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMBool, Bool: a.ToBool() && b.ToBool()})

	case OP_LOR:
		b := vm.pop()
		a := vm.pop()
		vm.push(VMValue{Type: VMBool, Bool: a.ToBool() || b.ToBool()})

	case OP_LNOT:
		a := vm.pop()
		vm.push(VMValue{Type: VMBool, Bool: !a.ToBool()})

	case OP_JMP:
		vm.RIP = inst.Arg1

	case OP_JZ:
		a := vm.pop()
		if !a.ToBool() {
			vm.RIP = inst.Arg1
		}

	case OP_JNZ:
		a := vm.pop()
		if a.ToBool() {
			vm.RIP = inst.Arg1
		}

	case OP_CALL:
		// Save frame
		if vm.FramePtr >= VMMaxCallDepth {
			panic("Call stack overflow")
		}
		vm.Frames[vm.FramePtr] = VMFrame{
			ReturnAddr: vm.RIP,
			BasePtr:    vm.RBP,
			Regs:       vm.Regs,
			Locals:     make(map[string]VMValue),
		}
		vm.FramePtr++
		vm.RBP = vm.RSP
		vm.RIP = inst.Arg1

	case OP_RET:
		if vm.FramePtr == 0 {
			vm.Running = false
			return
		}
		vm.FramePtr--
		frame := vm.Frames[vm.FramePtr]
		vm.RIP = frame.ReturnAddr
		vm.RBP = frame.BasePtr
		vm.Regs = frame.Regs

	case OP_SYSCALL:
		// Built-in function call
		funcName := string(vm.Heap[inst.Arg1:inst.Arg1+inst.Arg2])
		numArgs := int(inst.Arg3)
		args := make([]VMValue, numArgs)
		for i := numArgs - 1; i >= 0; i-- {
			args[i] = vm.pop()
		}
		if fn, ok := vm.Builtins[funcName]; ok {
			result := fn(vm, args)
			vm.push(result)
		} else {
			panic("Unknown built-in: " + funcName)
		}

	case OP_LOAD_MEM:
		addr := vm.pop().ToInt()
		vm.push(VMValue{Type: VMInt, Int: int64(vm.Heap[addr])})

	case OP_STORE_MEM:
		addr := vm.pop().ToInt()
		val := vm.pop()
		vm.Heap[addr] = byte(val.ToInt())

	case OP_ALLOC:
		size := vm.pop().ToInt()
		// Simple bump allocator
		addr := uint64(0) // TODO: proper heap allocation
		vm.push(VMValue{Type: VMPtr, Ptr: addr})

	case OP_FREE:
		vm.pop() // Just pop the pointer for now

	case OP_GET_FIELD:
		obj := vm.pop()
		fieldName := string(vm.Heap[inst.Arg1:inst.Arg1+inst.Arg2])
		if obj.Type == VMStruct {
			if val, ok := obj.Struct[fieldName]; ok {
				vm.push(val)
			} else {
				panic("Field not found: " + fieldName)
			}
		}

	case OP_SET_FIELD:
		val := vm.pop()
		obj := vm.pop()
		fieldName := string(vm.Heap[inst.Arg1:inst.Arg1+inst.Arg2])
		if obj.Type == VMStruct {
			obj.Struct[fieldName] = val
		}

	case OP_GET_INDEX:
		idx := vm.pop().ToInt()
		arr := vm.pop()
		if arr.Type == VMArray {
			if idx >= 0 && idx < int64(len(arr.Array)) {
				vm.push(arr.Array[idx])
			} else {
				panic("Array index out of bounds")
			}
		}

	case OP_SET_INDEX:
		val := vm.pop()
		idx := vm.pop().ToInt()
		arr := vm.pop()
		if arr.Type == VMArray {
			if idx >= 0 && idx < int64(len(arr.Array)) {
				arr.Array[idx] = val
			} else {
				panic("Array index out of bounds")
			}
		}

	case OP_I2F:
		a := vm.pop()
		vm.push(VMValue{Type: VMFloat, Float: float64(a.ToInt())})

	case OP_F2I:
		a := vm.pop()
		vm.push(VMValue{Type: VMInt, Int: int64(a.ToFloat())})

	case OP_I2S:
		a := vm.pop()
		vm.push(VMValue{Type: VMString, Str: strconv.FormatInt(a.ToInt(), 10)})

	case OP_S2I:
		a := vm.pop()
		num, _ := strconv.ParseInt(a.Str, 10, 64)
		vm.push(VMValue{Type: VMInt, Int: num})

	case OP_PRINT:
		val := vm.pop()
		vm.Output.WriteString(val.String())
		fmt.Print(val.String())

	case OP_SCAN:
		// Read input
		vm.push(VMValue{Type: VMString, Str: ""})

	case OP_TIMER:
		vm.push(VMValue{Type: VMInt, Int: 0})

	case OP_EXIT:
		code := 0
		if vm.RSP > 0 {
			code = int(vm.pop().ToInt())
		}
		vm.ExitCode = code
		vm.Running = false

	default:
		panic(fmt.Sprintf("Unknown opcode: %d", inst.Op))
	}
}

// ============================================================================
// HIGH-LEVEL EXECUTION
// ============================================================================

func (vm *VM) ExecuteString(code string) error {
	// Compile J++ code to VM bytecode
	// For now, just interpret simple expressions
	
	lexer := NewLexer("<vm>", code)
	tokens, err := lexer.Tokenize()
	if err != nil {
		return err
	}
	
	// Generate simple bytecode from tokens
	bytecode := vm.generateBytecode(tokens)
	vm.Load(bytecode)
	vm.Execute()
	
	return nil
}

func (vm *VM) generateBytecode(tokens []Token) []VMInstruction {
	// Simple bytecode generation for expressions
	// Full compiler would generate proper bytecode from AST
	
	var code []VMInstruction
	
	for i := 0; i < len(tokens); i++ {
		tok := tokens[i]
		
		switch tok.Type {
		case TokenIntLiteral:
			code = append(code, VMInstruction{Op: OP_LOADI, Arg1: uint64(tok.IntVal)})
			
		case TokenFloatLiteral:
			code = append(code, VMInstruction{Op: OP_LOADF, Arg1: math.Float64bits(tok.FloatVal)})
			
		case TokenStringLiteral:
			// Store string in heap
			heapAddr := uint64(len(vm.Heap))
			vm.Heap = append(vm.Heap, []byte(tok.StrVal)...)
			code = append(code, VMInstruction{Op: OP_LOADS, Arg1: heapAddr, Arg2: uint64(len(tok.StrVal))})
			
		case TokenBoolLiteral:
			val := uint64(0)
			if tok.BoolVal {
				val = 1
			}
			code = append(code, VMInstruction{Op: OP_LOADB, Arg1: val})
			
		case TokenPlus:
			code = append(code, VMInstruction{Op: OP_ADD})
			
		case TokenMinus:
			code = append(code, VMInstruction{Op: OP_SUB})
			
		case TokenStar:
			code = append(code, VMInstruction{Op: OP_MUL})
			
		case TokenSlash:
			code = append(code, VMInstruction{Op: OP_DIV})
			
		case TokenPercent:
			code = append(code, VMInstruction{Op: OP_MOD})
			
		case TokenEq:
			code = append(code, VMInstruction{Op: OP_EQ})
			
		case TokenNe:
			code = append(code, VMInstruction{Op: OP_NE})
			
		case TokenLt:
			code = append(code, VMInstruction{Op: OP_LT})
			
		case TokenGt:
			code = append(code, VMInstruction{Op: OP_GT})
			
		case TokenLe:
			code = append(code, VMInstruction{Op: OP_LE})
			
		case TokenGe:
			code = append(code, VMInstruction{Op: OP_GE})
			
		case TokenLogicalAnd:
			code = append(code, VMInstruction{Op: OP_LAND})
			
		case TokenLogicalOr:
			code = append(code, VMInstruction{Op: OP_LOR})
			
		case TokenLogicalNot:
			code = append(code, VMInstruction{Op: OP_LNOT})
			
		case TokenPrintel:
			// Handle printel function call
			if i+1 < len(tokens) && tokens[i+1].Type == TokenLParen {
				// Find matching )
				depth := 1
				j := i + 2
				for j < len(tokens) && depth > 0 {
					if tokens[j].Type == TokenLParen {
						depth++
					} else if tokens[j].Type == TokenRParen {
						depth--
					}
					j++
				}
				
				// Generate bytecode for arguments
				// ...
				
				// Call printel
				funcName := "printel"
				heapAddr := uint64(len(vm.Heap))
				vm.Heap = append(vm.Heap, []byte(funcName)...)
				code = append(code, VMInstruction{Op: OP_SYSCALL, Arg1: heapAddr, Arg2: uint64(len(funcName)), Arg3: 1})
			}
			
		case TokenScanel:
			funcName := "scanel"
			heapAddr := uint64(len(vm.Heap))
			vm.Heap = append(vm.Heap, []byte(funcName)...)
			code = append(code, VMInstruction{Op: OP_SYSCALL, Arg1: heapAddr, Arg2: uint64(len(funcName)), Arg3: 0})
			
		case TokenIdentifier:
			// Load variable from locals or registers
			// Simplified: use register 0
			code = append(code, VMInstruction{Op: OP_LOAD, Arg1: 0})
		}
	}
	
	code = append(code, VMInstruction{Op: OP_EXIT})
	
	return code
}


func (vm *VM) GetOutput() string {
	return vm.Output.String()
}

func (vm *VM) SetInput(input string) {
	vm.Input = input
	vm.InputPos = 0
}

func (vm *VM) GetExitCode() int {
	return vm.ExitCode
}

func (vm *VM) Reset() {
	vm.RIP = 0
	vm.RSP = 0
	vm.RBP = 0
	vm.FramePtr = 0
	vm.Running = false
	vm.ExitCode = 0
	vm.Output.Reset()
	vm.Input = ""
	vm.InputPos = 0
}

func (vm *VM) DumpState() string {
	var sb strings.Builder
	sb.WriteString("=== VM State ===\n")
	sb.WriteString(fmt.Sprintf("RIP: %d\n", vm.RIP))
	sb.WriteString(fmt.Sprintf("RSP: %d\n", vm.RSP))
	sb.WriteString(fmt.Sprintf("RBP: %d\n", vm.RBP))
	sb.WriteString(fmt.Sprintf("Running: %v\n", vm.Running))
	sb.WriteString(fmt.Sprintf("Exit Code: %d\n", vm.ExitCode))
	sb.WriteString("\nRegisters:\n")
	for i := 0; i < VMNumRegs; i++ {
		sb.WriteString(fmt.Sprintf("  R%d: %s\n", i, vm.Regs[i].String()))
	}
	sb.WriteString("\nStack (top 10):\n")
	start := uint64(0)
	if vm.RSP > 10 {
		start = vm.RSP - 10
	}
	for i := start; i < vm.RSP; i++ {
		sb.WriteString(fmt.Sprintf("  [%d]: %s\n", i, vm.Stack[i].String()))
	}
	sb.WriteString("\nOutput:\n")
	sb.WriteString(vm.GetOutput())
	sb.WriteString("\n")
	return sb.String()
}

func (vm *VM) DumpBytecode() string {
	var sb strings.Builder
	sb.WriteString("=== Bytecode ===\n")
	for i, inst := range vm.Code {
		sb.WriteString(fmt.Sprintf("%04d: %s\n", i, inst.String()))
	}
	return sb.String()
}
