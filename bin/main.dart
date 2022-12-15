// ignore_for_file: avoid_types_on_closure_parameters

import "dart:math" as math;

import "package:parser_combinator/parser_combinator.dart";

extension on num {
  num _factorialN(num n, num i) {
    if (n <= 0) {
      return i;
    }
    return _factorialN(n - 1, n * i);
  }

  num get factorial => _factorialN(this, 1);
}

extension on Object {
  R call<R>() => this as R;
}

Parser<num> expr() => add.$();
Parser<num> add() => choice.builder(() sync* {
      /// Addition can be `3 + 2` or `3 add 4`
      yield (add.$() + ["+", "add"].trie().trim() + mul.$()).map(($) => $[0]<num>() + $[2]<num>());

      /// Subtraction can be `5 - 2` or `5 sub 2`
      yield (add.$() + ["-", "sub"].trie().trim() + mul.$()).map(($) => $[0]<num>() - $[2]<num>());

      yield mul.$();
    });
Parser<num> mul() => choice.builder(() sync* {
      /// Multiplication can be `10 * 3` or `10 × 3` or `10 mul 3`
      yield (mul.$() + ["*", "×", "mul"].trie().trim() + pre.$()).map(($) => $[0]<num>() * $[2]<num>());

      /// Parenthesized multiplication
      yield (mul.$() + add.$().surrounded("(".s().trim(), ")".s().trim())).map(($) => $[0]<num>() * $[1]<num>());

      /// Division can be `9 / 3` or `9 ÷ 3` or `9 div 3`
      yield (mul.$() + ["/", "÷", "div"].trie().trim() + pre.$()).map(($) => $[0]<num>() / $[2]<num>());

      /// Floor division can be `24 ~/ 2` or `24 // 2` or `24 fdiv 2`
      yield (mul.$() + ["~/", "//", "fdiv"].trie().trim() + pre.$()).map(($) => $[0]<num>() ~/ $[2]<num>());

      /// Modulo can be `25 % 2` or `25 mod 2`
      yield (mul.$() + ["%", "mod"].trie().trim() + pre.$()).map(($) => $[0]<num>() % $[2]<num>());

      yield pre.$();
    });
Parser<num> pre() => choice.builder(() sync* {
      /// A negative can be negative.
      yield pre.$().prefix("-".s().trim()).map((v) => -v);

      /// A prefix factorial.
      yield pre.$().prefix("fac".s().trim()).map((v) => v.factorial);

      yield exp.$();
    });
Parser<num> exp() => choice.builder(() sync* {
      /// Exponentials are right-associative, so 2^2^2 = 2^(2^2).
      yield (fac.$() + "^".s().trim() + exp.$()).map(($) => math.pow($[0]<num>(), $[2]<num>()));

      yield fac.$();
    });
Parser<num> fac() => choice.builder(() sync* {
      /// Factorials. Self reference means that factorials of factorials are possible.
      yield fac.$().suffix("!".s().trim()).map((num v) => v.factorial);

      /// Any grouped.
      yield group.$();
    });
Parser<num> group() => choice.builder(() sync* {
      /// Absolute value
      yield add.$().surrounded("|".s().trim(), "|".s().trim()).map((num v) => v.abs());

      /// Parenthesized expression
      yield add.$().surrounded("(".s().trim(), ")".s().trim());

      /// Plain expressions
      yield plain.$();
    });
Parser<num> plain() => choice.builder(() sync* {
      /// Plain multiplication (i.e. `3 sin 5` -> `3 * sin 5`)
      yield (plain.$() + ["-", "("].trie().not() + group.$()).map(($) => $[0]<num>() * $[2]<num>());

      /// Parenthesized function call (i.e. `log-b(8, 2)` )
      yield (identifier().tr() + "(".s().trim() + add.$().separated(",".s().trim()) + ")".s().trim()).map(($) {
        String name = $[0]();
        List<num> arguments = $[2]();

        return evalFunction(name, arguments);
      });

      /// Non-parenthesized function call (i.e. `log-b 8, 2` )
      yield (identifier().tr() + "(".s().not() + add.$().separated(",".s().trim())).map(($) {
        String name = $[0]();
        List<num> arguments = $[2]();

        return evalFunction(name, arguments);
      });
      yield atomic.$();
    });
Parser<num> atomic() => choice.builder(() sync* {
      /// Any defined constant
      yield constants.keys.trie().map((k) => constants[k]!);

      /// A number with degree
      yield number.$().suffix(["deg", "°"].trie()).map((num v) => v * (math.pi / 180));

      /// A number with rad-specifier
      yield number.$().suffix(["rad", "r"].trie());

      /// A percentage
      yield number.$().suffix("%".s()).map((num v) => v / 100);

      yield number.$();
    });
Parser<num> number() => regex(r"(?:[0-9'_]*\.[0-9'_]+)|(?:[0-9'_]+)") //
    .map((v) => v.replaceAll(RegExp("['_]"), ""))
    .map(num.parse);

const double dx = 0.0000000001;
final Map<String, int> functionsArgc = <String, int>{
  "sin": 1,
  "cos": 1,
  "tan": 1,
  "asin": 1,
  "acos": 1,
  "atan": 1,
  "atan2": 2,
  "sec": 1,
  "csc": 1,
  "cot": 1,
  "log-b": 2,
  "log": 1,
  "ln": 1,
  "permutation": 2,
  "combination": 2,
  "sqrt": 1,
  "√": 1,
  "abs": 1,
  "floor": 1,
  "ceil": 1,
  "round": 1,
  "rad-to-deg": 1,
  "deg-to-rad": 1,
  "pow": 2,
  "root": 2,
  "fixed": 2,
};
final Map<String, Function> functions = <String, Function>{
  "sin": (num v) => math.sin(v % (2 * math.pi)),
  "cos": (num v) => math.cos(v % (2 * math.pi)),
  "tan": (num v) => math.tan(v % (2 * math.pi)),
  "sec": (num v) => 1 / math.cos(v % (2 * math.pi)),
  "csc": (num v) => 1 / math.sin(v % (2 * math.pi)),
  "cot": (num v) => 1 / math.tan(v % (2 * math.pi)),
  "asin": (num v) => math.asin(v),
  "acos": (num v) => math.acos(v),
  "atan": (num v) => math.atan(v),
  "atan2": (num a, num b) => math.atan2(a, b),
  "log-b": (num v, num b) => math.log(v) / math.log(b),
  "log": (num v) => math.log(v) / math.log(10),
  "ln": (num v) => math.log(v),
  "permutation": (num n, num r) => n.factorial ~/ (n - r).factorial,
  "combination": (num n, num r) => n.factorial ~/ (n - r).factorial ~/ r.factorial,
  "sqrt": (num v) => math.sqrt(v),
  "√": (num v) => math.sqrt(v),
  "abs": (num v) => v < 0 ? -v : v,
  "floor": (num v) => v.floor(),
  "ceil": (num v) => v.ceil(),
  "round": (num v) => v.round(),
  "rad-to-deg": (num v) => v * (180 / math.pi),
  "deg-to-rad": (num v) => v * (math.pi / 180),
  "pow": (num l, num r) => math.pow(l, r),
  "root": (num r, num v) => math.pow(v, 1 / r),
  "fixed": (num l, num f) => num.parse(l.toStringAsFixed(f.floor()))
};
final Map<String, num> constants = <String, num>{
  "pi": math.pi,
  "π": math.pi,
  "e": math.e,
  "phi": (1 + math.sqrt(5)) / 2,
  "φ": (1 + math.sqrt(5)) / 2,
};

num normalizeNum(num n, [int decimal = 16]) {
  if (n.isNaN || n.isInfinite) {
    return n;
  }

  if (n - n.floor() <= dx) {
    return n.floor();
  }

  if (-dx < n && n < dx) {
    return 0;
  }

  return double.parse(n.toStringAsFixed(decimal));
}

num evalFunction(String name, List<num> args) {
  Function? function = functions[name];
  int? argc = functionsArgc[name];

  if (function == null || argc == null) {
    print("Unknown function '$name'");
  }

  if (argc != args.length) {
    print("Function '$name' requires $argc arguments. Received ${args.length}");
  }

  num result = Function.apply(function!, args) as num;

  return result;
}

void main(List<String> arguments) {
  print(jsonNumberSlow());
  if (arguments.isEmpty) {
    print("No arguments given");
  }

  Parser<num> parser = expr.build();
  if (arguments[0] == "log") {
    String input = arguments.sublist(1).join();
    print(input);
    print(parser.peg(input).cst);
    print(parser.peg(input).tryUnwrap());
  } else {
    String input = arguments.join();

    print(normalizeNum(parser.peg(input).unwrap()));
  }
}
