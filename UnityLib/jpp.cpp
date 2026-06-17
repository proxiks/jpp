
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <regex>

using namespace std;

class JppToArduino {
private:
    string jppSource;
    string cppOutput;
    string asmOutput;
    
    // Target MCU config
    struct MCUConfig {
        string name;
        string core;
        int flash;
        int ram;
        int eeprom;
        int clock;
        map<string, int> pinMap;
    } mcu;
    
public:
    JppToArduino(string source) : jppSource(source) {
        // Default: Arduino Uno (ATmega328P)
        mcu = {
            "atmega328p",
            "avr",
            32768,      // 32KB flash
            2048,       // 2KB SRAM
            1024,       // 1KB EEPROM
            16000000,   // 16MHz
            {
                {"D0", 0}, {"D1", 1}, {"D2", 2}, {"D3", 3},
                {"D4", 4}, {"D5", 5}, {"D6", 6}, {"D7", 7},
                {"D8", 8}, {"D9", 9}, {"D10", 10}, {"D11", 11},
                {"D12", 12}, {"D13", 13},
                {"A0", 14}, {"A1", 15}, {"A2", 16}, {"A3", 17},
                {"A4", 18}, {"A5", 19}
            }
        };
    }
    
    string transpile() {
        stringstream out;
        stringstream asmOut;
        
        // === HEADER ===
        out << "// Auto-generated from J++\n";
        out << "// Target: " << mcu.name << "\n";
        out << "// Clock: " << (mcu.clock / 1000000) << "MHz\n\n";
        
        // === INCLUDES ===
        out << "#include <Arduino.h>\n";
        out << "#include <avr/io.h>\n";
        out << "#include <avr/interrupt.h>\n";
        out << "#include <avr/sleep.h>\n";
        out << "#include <avr/pgmspace.h>\n";
        out << "#include <EEPROM.h>\n\n";
        
        // === PIN DEFINITIONS ===
        out << "// === PIN DEFINITIONS ===\n";
        regex pinRegex(R"(pin\s+(\w+)\s*=\s*(D\d+|A\d+)\s*(?:\{\s*([^}]*)\s*\})?;)");
        smatch pinMatch;
        string temp = jppSource;
        
        while (regex_search(temp, pinMatch, pinRegex)) {
            string pinName = pinMatch[1];
            string pinNum = pinMatch[2];
            string pinConfig = pinMatch[3];
            
            int arduinoPin = mcu.pinMap[pinNum];
            out << "#define " << pinName << " " << arduinoPin << "\n";
            
            // Parse pin config
            if (pinConfig.find("INPUT_PULLUP") != string::npos) {
                out << "// " << pinName << ": INPUT_PULLUP\n";
            } else if (pinConfig.find("PWM") != string::npos) {
                out << "// " << pinName << ": PWM\n";
            }
            
            temp = pinMatch.suffix();
        }
        out << "\n";
        
        // === VOLATILE VARIABLES ===
        out << "// === VOLATILE VARIABLES ===\n";
        regex volatileRegex(R"(volatile\s+let\s+(\w+)\s*:\s*(\w+)\s*=\s*([^;]+);)");
        smatch volMatch;
        temp = jppSource;
        
        while (regex_search(temp, volMatch, volatileRegex)) {
            string varName = volMatch[1];
            string varType = jppTypeToCpp(volMatch[2]);
            string init = volMatch[3];
            
            out << "volatile " << varType << " " << varName << " = " << init << ";\n";
            temp = volMatch.suffix();
        }
        out << "\n";
        
        // === REGISTER VARIABLES (Assembly) ===
        out << "// === REGISTER VARIABLES ===\n";
        regex regRegex(R"(register\s+let\s+(\w+)\s*:\s*(\w+)\s*=\s*([^;]+);)");
        smatch regMatch;
        temp = jppSource;
        
        while (regex_search(temp, regMatch, regRegex)) {
            string varName = regMatch[1];
            string varType = jppTypeToCpp(regMatch[2]);
            string init = regMatch[3];
            
            // Register hint (compiler may ignore)
            out << "register " << varType << " " << varName << " = " << init << ";\n";
            temp = regMatch.suffix();
        }
        out << "\n";
        
        // === FLASH/PROGMEM DATA ===
        out << "// === FLASH DATA ===\n";
        regex flashRegex(R"(flash\s+let\s+(\w+)\s*:\s*\[(\w+);\s*(\d+)\]\s*=\s*\[([^]]*)\];)");
        smatch flashMatch;
        temp = jppSource;
        
        while (regex_search(temp, flashMatch, flashRegex)) {
            string varName = flashMatch[1];
            string elemType = flashMatch[2];
            int size = stoi(flashMatch[3]);
            string data = flashMatch[4];
            
            out << "const " << jppTypeToCpp(elemType) << " " << varName 
                << "[" << size << "] PROGMEM = {" << data << "};\n";
            temp = flashMatch.suffix();
        }
        out << "\n";
        
        // === EEPROM DATA ===
        out << "// === EEPROM DATA ===\n";
        regex eepromRegex(R"(eeprom\s+let\s+(\w+)\s*:\s*(\w+)\s*=\s*([^;]+);)");
        smatch eepromMatch;
        temp = jppSource;
        
        while (regex_search(temp, eepromMatch, eepromRegex)) {
            string varName = eepromMatch[1];
            string varType = jppTypeToCpp(eepromMatch[2]);
            string init = eepromMatch[3];
            
            out << "// EEPROM: " << varName << " (manual init required)\n";
            out << varType << " " << varName << "_default = " << init << ";\n";
            temp = eepromMatch.suffix();
        }
        out << "\n";
        
        // === ISR DECLARATIONS ===
        out << "// === ISR DECLARATIONS ===\n";
        regex isrRegex(R"(isr\s+(\w+)\s*\{([^}]*)\})");
        smatch isrMatch;
        temp = jppSource;
        
        while (regex_search(temp, isrMatch, isrRegex)) {
            string vectorName = isrMatch[1];
            string body = isrMatch[2];
            
            out << "ISR(" << vectorName << ") {\n";
            out << transpileBody(body, true);  // true = ISR context
            out << "}\n\n";
            
            temp = isrMatch.suffix();
        }
        
        // === NAKED ISR ===
        regex nakedRegex(R"(naked\s+isr\s+(\w+)\s*\{([^}]*)\}\s*;)");
        smatch nakedMatch;
        temp = jppSource;
        
        while (regex_search(temp, nakedMatch, nakedRegex)) {
            string vectorName = nakedMatch[1];
            string asmBody = nakedMatch[2];
            
            out << "ISR(" << vectorName << ", ISR_NAKED) {\n";
            out << "    __asm__ __volatile__ (\n";
            
            // Parse inline assembly
            regex asmLineRegex(R"("([^"]*)")");
            smatch asmLineMatch;
            string asmTemp = asmBody;
            
            while (regex_search(asmTemp, asmLineMatch, asmLineRegex)) {
                out << "        \"" << asmLineMatch[1] << "\\n\\t\"\n";
                asmTemp = asmLineMatch.suffix();
            }
            
            out << "    );\n";
            out << "}\n\n";
            
            temp = nakedMatch.suffix();
        }
        
        // === FUNCTIONS ===
        out << "// === FUNCTIONS ===\n";
        regex fnRegex(R"((?:inline\s+)?fn\s+(\w+)\s*\(([^)]*)\)(?:\s*->\s*(\w+))?\s*\{([^}]*)\})");
        smatch fnMatch;
        temp = jppSource;
        
        while (regex_search(temp, fnMatch, fnRegex)) {
            bool isInline = fnMatch[0].str().find("inline") != string::npos;
            string fnName = fnMatch[1];
            string params = fnMatch[2];
            string retType = fnMatch[3];
            string body = fnMatch[4];
            
            if (isInline) out << "inline ";
            out << jppTypeToCpp(retType.empty() ? "void" : retType) << " ";
            out << fnName << "(" << transpileParams(params) << ") {\n";
            out << transpileBody(body, false);
            out << "}\n\n";
            
            temp = fnMatch.suffix();
        }
        
        // === SETUP & LOOP ===
        out << "// === SETUP & LOOP ===\n";
        out << "void setup() {\n";
        
        // Extract setup block
        regex setupRegex(R"(setup\s*\{([^}]*)\})");
        smatch setupMatch;
        if (regex_search(jppSource, setupMatch, setupRegex)) {
            out << transpileBody(setupMatch[1], false);
        }
        
        out << "}\n\n";
        
        out << "void loop() {\n";
        
        // Extract loop block
        regex loopRegex(R"(loop\s*\{([^}]*)\})");
        smatch loopMatch;
        if (regex_search(jppSource, loopMatch, loopRegex)) {
            out << transpileBody(loopMatch[1], false);
        }
        
        out << "}\n";
        
        cppOutput = out.str();
        return cppOutput;
    }
    
    string generateAssembly() {
        stringstream asmOut;
        
        // === ASSEMBLY OUTPUT ===
        asmOut << "; Auto-generated Assembly from J++\n";
        asmOut << "; Target: " << mcu.name << "\n\n";
        
        asmOut << ".include \"m328pdef.inc\"\n\n";
        
        // === INTERRUPT VECTORS ===
        asmOut << ".org 0x0000\n";
        asmOut << "    rjmp RESET\n";
        asmOut << "    rjmp INT0_ISR\n";
        asmOut << "    rjmp INT1_ISR\n";
        asmOut << "    rjmp PCINT0_ISR\n";
        asmOut << "    rjmp PCINT1_ISR\n";
        asmOut << "    rjmp PCINT2_ISR\n";
        asmOut << "    rjmp WDT_ISR\n";
        asmOut << "    rjmp TIMER2_COMPA_ISR\n";
        asmOut << "    rjmp TIMER2_COMPB_ISR\n";
        asmOut << "    rjmp TIMER2_OVF_ISR\n";
        asmOut << "    rjmp TIMER1_CAPT_ISR\n";
        asmOut << "    rjmp TIMER1_COMPA_ISR\n";
        asmOut << "    rjmp TIMER1_COMPB_ISR\n";
        asmOut << "    rjmp TIMER1_OVF_ISR\n";
        asmOut << "    rjmp TIMER0_COMPA_ISR\n";
        asmOut << "    rjmp TIMER0_COMPB_ISR\n";
        asmOut << "    rjmp TIMER0_OVF_ISR\n";
        asmOut << "    rjmp SPI_STC_ISR\n";
        asmOut << "    rjmp USART_RX_ISR\n";
        asmOut << "    rjmp USART_UDRE_ISR\n";
        asmOut << "    rjmp USART_TX_ISR\n";
        asmOut << "    rjmp ADC_ISR\n";
        asmOut << "    rjmp EE_READY_ISR\n";
        asmOut << "    rjmp ANALOG_COMP_ISR\n";
        asmOut << "    rjmp TWI_ISR\n";
        asmOut << "    rjmp SPM_READY_ISR\n\n";
        
        // === RESET ===
        asmOut << "RESET:\n";
        asmOut << "    ; Initialize stack pointer\n";
        asmOut << "    ldi r16, LOW(RAMEND)\n";
        asmOut << "    out SPL, r16\n";
        asmOut << "    ldi r16, HIGH(RAMEND)\n";
        asmOut << "    out SPH, r16\n\n";
        
        asmOut << "    ; Call C++ constructors\n";
        asmOut << "    call main\n\n";
        
        // Extract assembly blocks from J++
        regex asmBlockRegex(R"(asm\s*\{([^}]*)\})");
        smatch asmMatch;
        string temp = jppSource;
        
        while (regex_search(temp, asmMatch, asmBlockRegex)) {
            string asmBody = asmMatch[1];
            
            // Parse assembly lines
            regex asmLineRegex(R"("([^"]*)")");
            smatch lineMatch;
            string lineTemp = asmBody;
            
            while (regex_search(lineTemp, lineMatch, asmLineRegex)) {
                string line = lineMatch[1];
                
                // Convert J++ asm syntax to AVR asm
                // sbi PORTB, 5 -> sbi 0x05, 5
                line = regex_replace(line, regex(R"(sbi\s+(\w+),\s*(\d+))"), 
                    "sbi _PORT_$1, $2");
                line = regex_replace(line, regex(R"(cbi\s+(\w+),\s*(\d+))"), 
                    "cbi _PORT_$1, $2");
                line = regex_replace(line, regex(R"(in\s+(\w+),\s*(\w+))"), 
                    "in $1, _SFR_IO_ADDR($2)");
                line = regex_replace(line, regex(R"(out\s+(\w+),\s+(\w+))"), 
                    "out _SFR_IO_ADDR($1), $2");
                
                asmOut << "    " << line << "\n";
                lineTemp = lineMatch.suffix();
            }
            
            temp = asmMatch.suffix();
        }
        
        // === ISRs in Assembly ===
        asmOut << "\n; === ISRs ===\n";
        
        regex isrRegex(R"(isr\s+(\w+)\s*\{([^}]*)\})");
        smatch isrMatch;
        temp = jppSource;
        
        while (regex_search(temp, isrMatch, isrRegex)) {
            string vectorName = isrMatch[1];
            string body = isrMatch[2];
            
            asmOut << vectorName << ":\n";
            asmOut << "    push r16\n";
            asmOut << "    in r16, _SFR_IO_ADDR(SREG)\n";
            asmOut << "    push r16\n\n";
            
            // Transpile body
            asmOut << transpileBodyToAsm(body);
            
            asmOut << "    pop r16\n";
            asmOut << "    out _SFR_IO_ADDR(SREG), r16\n";
            asmOut << "    pop r16\n";
            asmOut << "    reti\n\n";
            
            temp = isrMatch.suffix();
        }
        
        asmOutput = asmOut.str();
        return asmOutput;
    }
    
private:
    string jppTypeToCpp(string jppType) {
        if (jppType == "u8" || jppType == "uint8") return "uint8_t";
        if (jppType == "u16" || jppType == "uint16") return "uint16_t";
        if (jppType == "u32" || jppType == "uint32") return "uint32_t";
        if (jppType == "u64") return "uint64_t";
        if (jppType == "i8" || jppType == "int8") return "int8_t";
        if (jppType == "i16" || jppType == "int16") return "int16_t";
        if (jppType == "i32" || jppType == "int32") return "int32_t";
        if (jppType == "i64") return "int64_t";
        if (jppType == "f32" || jppType == "float") return "float";
        if (jppType == "f64" || jppType == "double") return "double";
        if (jppType == "bool") return "bool";
        if (jppType == "void") return "void";
        return jppType; // Custom types
    }
    
    string transpileParams(string params) {
        // J++: "speed: u8, dir: bool" -> C++: "uint8_t speed, bool dir"
        string result = params;
        result = regex_replace(result, regex(R"((\w+)\s*:\s*u8)"), "uint8_t $1");
        result = regex_replace(result, regex(R"((\w+)\s*:\s*u16)"), "uint16_t $1");
        result = regex_replace(result, regex(R"((\w+)\s*:\s*bool)"), "bool $1");
        return result;
    }
    
    string transpileBody(string body, bool isISR) {
        string result = body;
        
        // J++ -> C++ conversions
        result = regex_replace(result, regex(R"(let\s+(\w+)\s*:\s*(\w+)\s*=\s*([^;]+);)"),
            [&](const smatch& m) {
                return jppTypeToCpp(m[2].str()) + " " + m[1].str() + " = " + m[3].str() + ";";
            });
        
        result = regex_replace(result, regex(R"(fn\s+(\w+)\s*\()"), "$1(");
        result = regex_replace(result, regex(R"(match\s+(\w+)\s*\{)"), "switch ($1) {");
        result = regex_replace(result, regex(R"(\s*=>\s*\{)"), " {");
        result = regex_replace(result, regex(R"(digitalWrite\(([^,]+),\s*(HIGH|LOW)\))"), 
            "digitalWrite($1, $2)");
        result = regex_replace(result, regex(R"(digitalRead\(([^)]+)\))"), 
            "digitalRead($1)");
        result = regex_replace(result, regex(R"(analogRead\(([^)]+)\))"), 
            "analogRead($1)");
        result = regex_replace(result, regex(R"(delay\(([^)]+)\))"), 
            "delay($1)");
        result = regex_replace(result, regex(R"(millis\(\))"), 
            "millis()");
        result = regex_replace(result, regex(R"(micros\(\))"), 
            "micros()");
        result = regex_replace(result, regex(R"(Serial\.begin\(([^)]+)\))"), 
            "Serial.begin($1)");
        result = regex_replace(result, regex(R"(Serial\.print\(([^)]+)\))"), 
            "Serial.print($1)");
        result = regex_replace(result, regex(R"(Serial\.println\(([^)]*)\))"), 
            "Serial.println($1)");
        result = regex_replace(result, regex(R"(pinMode\(([^,]+),\s*([^)]+)\))"), 
            "pinMode($1, $2)");
        result = regex_replace(result, regex(R"(digitalToggle\(([^)]+)\))"), 
            "digitalWrite($1, !digitalRead($1))");
        result = regex_replace(result, regex(R"(tone\(([^,]+),\s*([^,]+)(?:,\s*([^)]+))?\))"), 
            "tone($1, $2$3)");
        result = regex_replace(result, regex(R"(noTone\(([^)]+)\))"), 
            "noTone($1)");
        result = regex_replace(result, regex(R"(sei\(\))"), 
            "sei()");
        result = regex_replace(result, regex(R"(cli\(\))"), 
            "cli()");
        result = regex_replace(result, regex(R"(sleep_mode\(([^)]+)\))"), 
            "set_sleep_mode($1); sleep_mode()");
        
        // Static variables in loop
        result = regex_replace(result, regex(R"(static\s+let\s+(\w+)\s*:\s*(\w+)\s*=\s*([^;]+);)"),
            "static " + string("$2") + " $1 = $3;");
        
        // Bit operations
        result = regex_replace(result, regex(R"((\w+)\.(\w+)\s*=\s*(true|false))"),
            "$1 = ($3) ? ($1 | (1 << $2)) : ($1 & ~(1 << $2))");
        
        return result;
    }
    
    string transpileBodyToAsm(string body) {
        stringstream asmOut;
        
        // Simple transpilation to AVR assembly
        // This is a simplified version — real implementation would be more complex
        
        regex writeRegex(R"(digitalWrite\(([^,]+),\s*(HIGH|LOW)\))");
        smatch writeMatch;
        string temp = body;
        
        while (regex_search(temp, writeMatch, writeRegex)) {
            string pin = writeMatch[1];
            string val = writeMatch[2];
            
            if (val == "HIGH") {
                asmOut << "    sbi _SFR_IO_ADDR(PORTB), " << pin << "\n";
            } else {
                asmOut << "    cbi _SFR_IO_ADDR(PORTB), " << pin << "\n";
            }
            
            temp = writeMatch.suffix();
        }
        
        // Read operations
        regex readRegex(R"(digitalRead\(([^)]+)\))");
        smatch readMatch;
        temp = body;
        
        while (regex_search(temp, readMatch, readRegex)) {
            asmOut << "    in r16, _SFR_IO_ADDR(PINB)\n";
            asmOut << "    andi r16, (1 << " << readMatch[1] << ")\n";
            temp = readMatch.suffix();
        }
        
        return asmOut.str();
    }
};

// === MAIN ===
int main(int argc, char* argv[]) {
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " <input.jpp> [output.cpp]\n";
        return 1;
    }
    
    // Read J++ source
    ifstream inFile(argv[1]);
    if (!inFile) {
        cerr << "Error: Cannot open " << argv[1] << "\n";
        return 1;
    }
    
    stringstream buffer;
    buffer << inFile.rdbuf();
    string source = buffer.str();
    
    // Transpile
    JppToArduino transpiler(source);
    string cpp = transpiler.transpile();
    string asm_code = transpiler.generateAssembly();
    
    // Write C++ output
    string cppFile = (argc > 2) ? argv[2] : "output.cpp";
    ofstream outFile(cppFile);
    outFile << cpp;
    outFile.close();
    
    // Write Assembly output
    string asmFile = cppFile + ".S";
    ofstream asmOutFile(asmFile);
    asmOutFile << asm_code;
    asmOutFile.close();
    
    cout << "Transpiled to: " << cppFile << "\n";
    cout << "Assembly: " << asmFile << "\n";
    
    return 0;
}
