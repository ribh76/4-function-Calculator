

// ===================== Scientific Calculator (Processing / Java) =====================
//  - 5 x 10 keypad layout (numpad bottom-left, operators on the right)
//  - Expression entry with caret + arrow keys (keyboard and on-screen)
//  - Shift/2nd alternate functions (auto-off after use)
//  - DEG/RAD toggle, memory (MC/MR/M+/M-), constants, functions, combinatorics, EE
// =====================================================================================

import java.text.DecimalFormat;
import java.util.*;
import java.util.regex.*;

PFont f;

ArrayList<Button> buttons = new ArrayList<Button>();
int COLS = 5, ROWS = 10;
int margin = 16, gap = 10;
int bh = 56; // button height
int bw;      // computed in setup
int panelTop = 130;

Editor editor = new Editor();
SciEngine engine = new SciEngine(); // expression evaluator (DEG/RAD, memory, Ans)
boolean shift = false;              // 2nd key toggle

void setup() {
  size(580, 930);
  f = createFont("Arial", 22, true);
  textFont(f);

  int totalContentWidth = width - (2 * margin);
  int totalGapWidth = gap * (COLS - 1);
  bw = (totalContentWidth - totalGapWidth) / COLS;

  makeButtons();
}

void draw() {
  background(18);
  drawDisplay();
  for (Button b : buttons) b.draw();
}

void mousePressed() {
  // Dispatch to buttons
  for (Button b : buttons) {
    if (b.hit(mouseX, mouseY)) { b.onClick.run(); break; }
  }
}

void keyPressed() {
  // Keyboard entry + arrows
  if (key >= '0' && key <= '9') insertText(""+key);
  else if (key=='.') insertText(".");
  else if (key=='+' || key=='-' || key=='*' || key=='/' || key=='^') {
    String op = (key=='*') ? "×" : (key=='/') ? "÷" : ""+key;
    insertOp(op);
  } else if (key=='(' || key==')') insertText(""+key);
  else if (key=='\n' || key=='=') doEquals();
  else if (key=='c' || key=='C') clearAll();
  else if (key==BACKSPACE || key==DELETE) editor.backspace();
  else if (keyCode==LEFT) editor.moveLeft();
  else if (keyCode==RIGHT) editor.moveRight();
  else if (keyCode==UP) editor.historyPrev();
  else if (keyCode==DOWN) editor.historyNext();
}

void drawDisplay() {
  // Display bezel
  noStroke();
  fill(26);
  rect(margin, 16, width-2*margin, 96, 18);
  fill(30);
  rect(margin+6, 22, width-2*margin-12, 84, 14);

  // Status row (mode + memory)
  fill(150);
  textAlign(LEFT, CENTER);
  textSize(16);
  String memFlag = Math.abs(engine.memoryRecall()) > 1e-15 ? "  M" : "";
  String modeStr = "MODE: " + (engine.getAngleMode()==AngleMode.DEG ? "DEG" : "RAD");

  // Expression text + caret
  String expr = editor.getExpr();
  // taken as-is; rendering with caret:
  float left = margin+18;
  float right = width - margin - 18;
  textAlign(LEFT, CENTER);
  textSize(22);
  fill(180);
  // clip area
  pushMatrix();
  pushStyle();
  // draw expression
  float yExpr = 72;
  String pre = expr.substring(0, editor.caret);
  String post = expr.substring(editor.caret);
  text(pre, left, yExpr);
  float caretX = left + textWidth(pre);
  // caret
  stroke(230);
  if ((frameCount/30)%2==0) line(caretX, yExpr-16, caretX, yExpr+16);
  noStroke();
  text(post, caretX, yExpr);
  popStyle();
  popMatrix();

  // Result line (current evaluated value if last result)
  textAlign(RIGHT, CENTER);
  textSize(36);
  fill(235);
  String disp = editor.errorBanner != null ? editor.errorBanner : editor.lastShown;
  text(disp, right, 104);
}

void makeButtons() {
  // Layout: 5 cols x 10 rows (top -> bottom)
  // Rightmost col are the main ops
  // 2nd behavior shows alternates (asin, acos, atan, e^x, 10^x, x^2, x^3, etc.)
  String[][] grid = {
    // r0
    {"2nd", "MC", "MR", "M+", "÷"},
    // r1
    {"DEG", "(", ")", "M-", "×"},
    // r2
    {"π", "e", "EE", "^", "-"},
    // r3
    {"sin", "cos", "tan", "mod", "+"},
    // r4
    {"ln", "log", "√", "x^2", "="},
    // r5
    {"abs", "round", "floor", "ceil", "←"},
    // r6  (numpad starts)
    {"7", "8", "9", "1/x", "→"},
    // r7
    {"4", "5", "6", "x^3", "←︎"},  // on-screen left arrow (label alt)
    // r8
    {"1", "2", "3", "nCr", "↑"},
    // r9
    {"0", ".", "±", "nPr", "↓"}
  };

  // We render specific arrow labels for clarity
  // Replace placeholders with nice glyphs
  for (int r=0;r<ROWS;r++){
    for (int c=0;c<COLS;c++){
      String lab = grid[r][c];
      if (lab.equals("←︎")) grid[r][c] = "◀";
    }
  }

  for (int r=0; r<ROWS; r++) {
    for (int c=0; c<COLS; c++) {
      String label = grid[r][c];
      if (label.equals("")) continue;
      int x = margin + c * (bw + gap);
      int y = panelTop + r * (bh + gap);
      Runnable action = makeAction(label);
      buttons.add(new Button(x, y, bw, bh, label, action, kindOf(label)));
    }
  }
}

enum Kind { OP, NUM, MEM, FUNC, UTIL }
Kind kindOf(String s){
  if ("+-×÷=^".indexOf(s)!=-1 || s.equals("mod")) return Kind.OP;
  if (s.length()==1 && s.charAt(0)>='0' && s.charAt(0)<='9') return Kind.NUM;
  if (s.startsWith("M")) return Kind.MEM;
  if (Arrays.asList("DEG","2nd","(",")","EE","±","←","→","◀","↑","↓","←").contains(s)) return Kind.UTIL;
  return Kind.FUNC;
}

Runnable makeAction(String lab) {
  switch(lab) {
    // --- toggles / util ---
    case "2nd": return ()->{ shift = !shift; };                 // shift latch
    case "DEG": return ()->{ engine.setAngleMode(engine.getAngleMode()==AngleMode.DEG ? AngleMode.RAD : AngleMode.DEG); };
    case "←":   return ()->{ editor.backspace(); };
    case "→":   return ()->{ editor.moveRight(); };
    case "◀":   return ()->{ editor.moveLeft(); };
    case "↑":   return ()->{ editor.historyPrev(); };
    case "↓":   return ()->{ editor.historyNext(); };

    // --- memory ---
    case "MC":  return ()->{ engine.memoryClear(); };
    case "MR":  return ()->{ insertText(trimNum(engine.memoryRecall())); };
    case "M+":  return ()->{ engine.memoryAdd(evalOrAns()); };
    case "M-":  return ()->{ engine.memorySub(evalOrAns()); };

    // --- constants & basic inserts ---
    case "π":   return ()->{ insertText("pi"); };
    case "e":   return ()->{ insertText("e"); };
    case "EE":  return ()->{ insertText("E"); };     // scientific notation
    case "(":   return ()->{ insertText("("); };
    case ")":   return ()->{ insertText(")"); };

    // --- digits & dot ---
    case "0": case "1": case "2": case "3": case "4":
    case "5": case "6": case "7": case "8": case "9":
    case ".":   return ()->{ insertText(lab); };

    // --- operators ---
    case "+": case "-": case "×": case "÷": case "^": case "mod":
      return ()->{ insertOp(lab); };

    // --- equals ---
    case "=":   return ()->{ doEquals(); };

    // --- sign ---
    case "±":   return ()->{ insertText("NEG("); insertText(")"); editor.moveLeft(); }; // wraps next token; simple way: NEG(x)

    // --- functions & their 2nd forms ---
    case "sin": return ()->{ if(consumeShift()) insertText("asin("); else insertText("sin("); };
    case "cos": return ()->{ if(consumeShift()) insertText("acos("); else insertText("cos("); };
    case "tan": return ()->{ if(consumeShift()) insertText("atan("); else insertText("tan("); };
    case "ln":  return ()->{ if(consumeShift()) insertText("exp("); else insertText("ln("); };
    case "log": return ()->{ if(consumeShift()) insertText("pow10("); else insertText("log("); }; // log = log10
    case "√":   return ()->{ if(consumeShift()) insertText("^2"); else insertText("sqrt("); };
    case "x^2": return ()->{ if(consumeShift()) insertText("sqrt("); else insertText("^2"); };
    case "1/x": return ()->{ insertText("1/("); };
    case "x^3": return ()->{ if(consumeShift()) insertText("cbrt("); else insertText("^3"); };
    case "abs": return ()->{ insertText("abs("); };
    case "round": return ()->{ insertText("round("); };
    case "floor": return ()->{ insertText("floor("); };
    case "ceil":  return ()->{ insertText("ceil("); };
    case "nCr":   return ()->{ insertOp("nCr"); };
    case "nPr":   return ()->{ insertOp("nPr"); };

    default: return ()->{};
  }
}

// consume shift state (auto-off after use)
boolean consumeShift(){
  if (shift) { shift = false; return true; }
  return false;
}

// --- editing helpers ---
void insertText(String s){ editor.insert(s); }
void insertOp(String op){
  // space-pad ops (optional); engine ignores whitespace anyway
  if (!editor.atStart() && !editor.peekLeft().equals("(")) editor.insert(" ");
  editor.insert(op);
  editor.insert(" ");
}
void doEquals(){
  String expr = editor.getExpr();
  try {
    double v = engine.evaluate(expr);
    editor.showResult(trimNum(v));
    // save to history
    editor.pushHistory(expr);
  } catch (Exception ex) {
    editor.showError("Error");
  }
}
void clearAll(){
  editor.clear();
}

// trim numeric display
String trimNum(double v){
  DecimalFormat fmt = new DecimalFormat("0.############");
  return fmt.format(v);
}
double evalOrAns(){
  try { return engine.evaluate(editor.getExpr()); }
  catch(Exception ex){ return engine.lastResult(); }
}

// ================================ UI: Button ==================================
class Button {
  int x,y,w,h;
  String label;
  Runnable onClick;
  Kind kind;
  Button(int x,int y,int w,int h,String label,Runnable onClick, Kind kind){
    this.x=x; this.y=y; this.w=w; this.h=h; this.label=label; this.onClick=onClick; this.kind=kind;
  }
  void draw(){
    noStroke();
    int bg;
    switch(kind){
      case OP:   bg = color(255,149,0); break; // orange
      case NUM:  bg = color(52); break;        // dark for digits
      case MEM:  bg = color(30,120,160); break;// teal for memory
      case FUNC: bg = color(64); break;        // mid-gray for functions
      default:   bg = color(48); break;        // util
    }
    fill(bg);
    rect(x, y, w, h, 12);
    fill(245);
    textAlign(CENTER, CENTER);
    textSize( (label.length()>=3 ? 18 : 22) );
    text(label, x+w/2, y+h/2);
  }
  boolean hit(int mx,int my){ return mx>=x && mx<=x+w && my>=y && my<=y+h; }
}

// =============================== Editor (caret, history) ======================
class Editor {
  StringBuilder sb = new StringBuilder();
  int caret = 0;                 // caret position in sb
  String lastShown = "0";        // last result line
  String errorBanner = null;
  ArrayList<String> history = new ArrayList<String>();
  int histIdx = -1;

  String getExpr(){ return sb.toString(); }
  void insert(String s){
    sb.insert(caret, s);
    caret += s.length();
    errorBanner = null;
  }
  boolean atStart(){ return caret<=0; }
  String peekLeft(){ if (caret<=0) return ""; return sb.substring(caret-1, caret); }
  void backspace(){
    if (caret<=0) return;
    sb.deleteCharAt(caret-1);
    caret--;
  }
  void moveLeft(){ if (caret>0) caret--; }
  void moveRight(){ if (caret<sb.length()) caret++; }

  void pushHistory(String expr){
    if (expr.trim().isEmpty()) return;
    history.add(expr);
    histIdx = history.size();
  }
  void historyPrev(){
    if (history.isEmpty()) return;
    histIdx = max(0, histIdx-1);
    loadHistory();
  }
  void historyNext(){
    if (history.isEmpty()) return;
    histIdx = min(history.size()-1, histIdx+1);
    loadHistory();
  }
  void loadHistory(){
    String h = history.get(histIdx);
    sb = new StringBuilder(h);
    caret = sb.length();
  }
  void showResult(String s){
    lastShown = s;
    errorBanner = null;
    // also set Ans
  }
  void showError(String s){
    errorBanner = s;
  }
  void clear(){
    sb = new StringBuilder();
    caret = 0;
    errorBanner = null;
    lastShown = "0";
  }
}

// =============================== Scientific Engine ============================
// Tokenizer -> RPN (Shunting Yard) -> Eval
// =============================== Scientific Engine (fixed for Processing) ============================
// Tokenizer -> RPN (Shunting Yard) -> Eval  (classic switch syntax; no "case ->", no multi-label cases)

enum AngleMode { DEG, RAD }
enum TT { NUM, OP, LP, RP, FUNC, ARGSEP, VAR }
interface IFunc { double f(double x); }


class SciEngine {
  private double memory = 0.0;
  private double last = 0.0;
  private AngleMode angleMode = AngleMode.DEG;

  // operator + function registries (instance, not static)
  private final Map<String,Op> OPS = new HashMap<String,Op>();
  private final Map<String,IFunc> FUNCS = new HashMap<String,IFunc>();

  // number/identifier patterns (instance, not static)
  private final Pattern NUM   = Pattern.compile("\\G(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:[eE][\\+\\-]?\\d+)?");
  private final Pattern IDENT = Pattern.compile("\\G[a-zA-Z_][a-zA-Z_0-9]*");

  SciEngine(){
    // operators
    OPS.put("+",   new Op(2,false,2));
    OPS.put("-",   new Op(2,false,2));
    OPS.put("*",   new Op(3,false,2));
    OPS.put("/",   new Op(3,false,2));
    OPS.put("^",   new Op(4,true, 2));
    OPS.put("NEG", new Op(5,true, 1)); // unary minus
    OPS.put("!",   new Op(6,true, 1)); // postfix factorial
    OPS.put("nCr", new Op(3,false,2));
    OPS.put("nPr", new Op(3,false,2));
    OPS.put("mod", new Op(3,false,2));

    // functions (anonymous classes to avoid lambda issues)
    FUNCS.put("sqrt",  new IFunc(){ public double f(double x){ return rootCheck(x); }});
    FUNCS.put("ln",    new IFunc(){ public double f(double x){ return Math.log(posReq(x)); }});
    FUNCS.put("log",   new IFunc(){ public double f(double x){ return Math.log10(posReq(x)); }});
    FUNCS.put("exp",   new IFunc(){ public double f(double x){ return Math.exp(x); }});
    FUNCS.put("pow10", new IFunc(){ public double f(double x){ return Math.pow(10.0, x); }});
    FUNCS.put("abs",   new IFunc(){ public double f(double x){ return Math.abs(x); }});
    FUNCS.put("floor", new IFunc(){ public double f(double x){ return Math.floor(x); }});
    FUNCS.put("ceil",  new IFunc(){ public double f(double x){ return Math.ceil(x); }});
    FUNCS.put("round", new IFunc(){ public double f(double x){ return (double)Math.round(x); }});
    FUNCS.put("sin",   new IFunc(){ public double f(double x){ return Math.sin( angleMode==AngleMode.DEG ? Math.toRadians(x) : x ); }});
    FUNCS.put("cos",   new IFunc(){ public double f(double x){ return Math.cos( angleMode==AngleMode.DEG ? Math.toRadians(x) : x ); }});
    FUNCS.put("tan",   new IFunc(){ public double f(double x){ return Math.tan( angleMode==AngleMode.DEG ? Math.toRadians(x) : x ); }});
    FUNCS.put("asin",  new IFunc(){ public double f(double x){ double y=clamp(x); return angleMode==AngleMode.DEG ? Math.toDegrees(Math.asin(y)) : Math.asin(y); }});
    FUNCS.put("acos",  new IFunc(){ public double f(double x){ double y=clamp(x); return angleMode==AngleMode.DEG ? Math.toDegrees(Math.acos(y)) : Math.acos(y); }});
    FUNCS.put("atan",  new IFunc(){ public double f(double x){ return angleMode==AngleMode.DEG ? Math.toDegrees(Math.atan(x)) : Math.atan(x); }});
    FUNCS.put("cbrt",  new IFunc(){ public double f(double x){ return Math.cbrt(x); }});
  }

  // --- public API ---
  public void setAngleMode(AngleMode m){ angleMode = m; }
  public AngleMode getAngleMode(){ return angleMode; }
  public void memoryClear(){ memory = 0.0; }
  public void memoryAdd(double v){ memory += v; }
  public void memorySub(double v){ memory -= v; }
  public double memoryRecall(){ return memory; }
  public double lastResult(){ return last; }

  public double evaluate(String expr){
    String s = normalize(expr);
    List<Token> toks = tokenize(s);
    List<Token> rpn  = toRPN(toks);
    double v = evalRPN(rpn);
    last = v;
    return v;
  }

  // --- internals ---
  private String normalize(String s){
    return s.replace('×','*')
            .replace('÷','/')
            .replaceAll("\\s+","")
            .replaceAll("Ans","ans");
  }

  private class Token {
    TT t; String s; double v;
    Token(TT t, String s){ this.t=t; this.s=s; }
    Token(double v){ this.t=TT.NUM; this.v=v; this.s=Double.toString(v); }
  }
  private class Op {
    final int prec; final boolean rightAssoc; final int arity;
    Op(int p, boolean r, int a){ prec=p; rightAssoc=r; arity=a; }
  }

  private List<Token> tokenize(String s){
    ArrayList<Token> out = new ArrayList<Token>();
    int i=0; boolean expectUnary = true;
    while (i<s.length()){
      char c = s.charAt(i);
      if (Character.isDigit(c) || c=='.'){
        Matcher m = NUM.matcher(s); m.region(i, s.length());
        if (!m.find()) throw new RuntimeException("Bad number");
        double v = Double.parseDouble(m.group());
        out.add(new Token(v));
        i = m.end();
        expectUnary = false;
      } else if (Character.isLetter(c) || c=='_'){
        Matcher m = IDENT.matcher(s); m.region(i, s.length());
        if (!m.find()) throw new RuntimeException("Bad ident");
        String id  = m.group();
        String lid = id.toLowerCase(Locale.ROOT);
        if (lid.equals("ans") || lid.equals("mr") || lid.equals("pi") || lid.equals("e")) {
          out.add(new Token(TT.VAR, lid));
        } else if (lid.equals("ncr") || lid.equals("npr") || lid.equals("mod")) {
          out.add(new Token(TT.OP, lid));
        } else if (FUNCS.containsKey(lid)) {
          out.add(new Token(TT.FUNC, lid));
        } else {
          out.add(new Token(TT.FUNC, lid)); // fallback treat as func name
        }
        i = m.end();
        expectUnary = false;
      } else if (c=='('){ out.add(new Token(TT.LP,"(")); i++; expectUnary=true; }
        else if (c==')'){ out.add(new Token(TT.RP,")")); i++; expectUnary=false; }
        else if (c==','){ out.add(new Token(TT.ARGSEP,",")); i++; }
        else if ("+-*/^!".indexOf(c)>=0){
          String op = String.valueOf(c);
          if (op.equals("-") && expectUnary) op = "NEG";
          out.add(new Token(TT.OP, op));
          i++; expectUnary = true;
        } else {
          throw new RuntimeException("Unexpected char: "+c);
        }
    }
    return out;
  }

  private List<Token> toRPN(List<Token> ts){
    ArrayList<Token> out = new ArrayList<Token>();
    Deque<Token> stack  = new ArrayDeque<Token>();
    for (int i=0;i<ts.size();i++){
      Token t = ts.get(i);
      switch (t.t){
        case NUM:
        case VAR:
          out.add(t);
          break;
        case FUNC:
          stack.push(t);
          break;
        case ARGSEP: {
          while (!stack.isEmpty() && stack.peek().t!=TT.LP) out.add(stack.pop());
          if (stack.isEmpty()) throw new RuntimeException("Comma err");
          break;
        }
        case OP: {
          Op o1 = OPS.get(t.s);
          if (o1==null) throw new RuntimeException("Unknown op "+t.s);
          while (!stack.isEmpty() && stack.peek().t==TT.OP){
            Op o2 = OPS.get(stack.peek().s);
            boolean cond = o1.rightAssoc ? o1.prec < o2.prec : o1.prec <= o2.prec;
            if (cond) out.add(stack.pop()); else break;
          }
          stack.push(t);
          break;
        }
        case LP:
          stack.push(t);
          break;
        case RP: {
          while (!stack.isEmpty() && stack.peek().t!=TT.LP) out.add(stack.pop());
          if (stack.isEmpty()) throw new RuntimeException("Paren err");
          stack.pop(); // pop '('
          if (!stack.isEmpty() && stack.peek().t==TT.FUNC) out.add(stack.pop());
          break;
        }
        default:
          throw new RuntimeException("Bad token");
      }
    }
    while(!stack.isEmpty()){
      Token x = stack.pop();
      if (x.t==TT.LP || x.t==TT.RP) throw new RuntimeException("Paren err");
      out.add(x);
    }
    return out;
  }

  private double evalRPN(List<Token> rpn){
    Deque<Double> st = new ArrayDeque<Double>();
    for (Token t : rpn){
      switch (t.t){
        case NUM:
          st.push(t.v);
          break;
        case VAR: {
          if ("ans".equals(t.s)) st.push(last);
          else if ("mr".equals(t.s)) st.push(memory);
          else if ("pi".equals(t.s)) st.push(Math.PI);
          else if ("e".equals(t.s))  st.push(Math.E);
          else throw new RuntimeException("Unknown var "+t.s);
          break;
        }
        case OP: {
          Op o = OPS.get(t.s);
          if (o.arity==1){
            if (st.isEmpty()) throw new RuntimeException("Missing arg");
            double a = st.pop();
            if (t.s.equals("NEG")) st.push(-a);
            else if (t.s.equals("!")) st.push(fact(a));
            else throw new RuntimeException("Bad unary op");
          } else {
            if (st.size()<2) throw new RuntimeException("Missing args");
            double b = st.pop(), a = st.pop();
            if (t.s.equals("+")) st.push(a+b);
            else if (t.s.equals("-")) st.push(a-b);
            else if (t.s.equals("*")) st.push(a*b);
            else if (t.s.equals("/")) { if (Math.abs(b)<1e-15) throw new RuntimeException("Div0"); st.push(a/b); }
            else if (t.s.equals("^")) st.push(Math.pow(a,b));
            else if (t.s.equals("nCr")) st.push(nCr(a,b));
            else if (t.s.equals("nPr")) st.push(nPr(a,b));
            else if (t.s.equals("mod")) { if (Math.abs(b)<1e-15) throw new RuntimeException("Div0"); st.push(a % b); }
            else throw new RuntimeException("Bad op");
          }
          break;
        }
        case FUNC: {
          if (st.isEmpty()) throw new RuntimeException("Missing arg");
          IFunc f = FUNCS.get(t.s);
          if (f==null) throw new RuntimeException("Unknown func "+t.s);
          st.push(f.f(st.pop()));
          break;
        }
        default:
          throw new RuntimeException("Bad token");
      }
    }
    if (st.size()!=1) throw new RuntimeException("Bad expr");
    return st.pop();
  }

  // helpers (instance, not static)
  private double posReq(double x){ if (x<=0) throw new RuntimeException("Domain"); return x; }
  private double rootCheck(double x){ if (x<0) throw new RuntimeException("Domain"); return Math.sqrt(x); }
  private double clamp(double x){ if (x<-1||x>1) throw new RuntimeException("Domain"); return x; }

  private double fact(double x){
    if (x<0 || Math.floor(x)!=x) throw new RuntimeException("Domain");
    double r = 1.0;
    for (int i=2;i<= (int)x; i++){ r *= i; if (Double.isInfinite(r)) throw new RuntimeException("Overflow"); }
    return r;
  }
  private double nCr(double na, double rb){
    if (!isInt(na) || !isInt(rb)) throw new RuntimeException("Domain");
    int n=(int)na, r=(int)rb; if (n<0||r<0||r>n) throw new RuntimeException("Domain");
    int k = Math.min(r, n-r);
    double res=1.0;
    for (int i=1;i<=k;i++) res = res * (n - k + i) / i;
    return res;
  }
  private double nPr(double na, double rb){
    if (!isInt(na) || !isInt(rb)) throw new RuntimeException("Domain");
    int n=(int)na, r=(int)rb; if (n<0||r<0||r>n) throw new RuntimeException("Domain");
    double res=1.0; for (int i=0;i<r;i++) res *= (n-i); return res;
  }
  private boolean isInt(double x){ return Math.floor(x)==x; }
}

//DONE :)
