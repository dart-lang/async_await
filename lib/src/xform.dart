// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library async_await.src.xform;

import 'package:analyzer/src/generated/ast.dart' as ast;
import 'package:analyzer/src/generated/scanner.dart' as scanner;
import 'package:analyzer/src/generated/testing/token_factory.dart';

import 'package:async_await/src/ast_factory.dart' as make;

class WorklistItem {
  final int position;
  final ast.FunctionBody sourceBody;

  WorklistItem(this.position, this.sourceBody);
}

class WorklistBuilder extends ast.RecursiveAstVisitor {
  final List<WorklistItem> worklist = <WorklistItem>[];
  visit(ast.AstNode node) => node.accept(this);

  visitExpressionFunctionBody(ast.ExpressionFunctionBody node) {
    if (node.isAsynchronous || node.isGenerator) {
      worklist.add(new WorklistItem(node.keyword.offset, node));
    } else {
      super.visitExpressionFunctionBody(node);
    }
  }

  visitBlockFunctionBody(ast.BlockFunctionBody node) {
    if (node.isAsynchronous || node.isGenerator) {
      worklist.add(new WorklistItem(node.keyword.offset, node));
    } else {
      super.visitBlockFunctionBody(node);
    }
  }
}

class Analysis extends ast.GeneralizingAstVisitor<bool> {
  Set<ast.AstNode> awaits = new Set<ast.AstNode>();
  Map<ast.Statement, List<ast.Label>> labels =
      <ast.Statement, List<ast.Label>>{};
  Set<String> names = new Set<String>();

  bool maybeAdd(ast.AstNode node, bool shouldAdd) {
    if (shouldAdd) awaits.add(node);
    return shouldAdd;
  }

  bool visit(ast.AstNode node) => node.accept(this);

  bool visitNode(ast.AstNode node) {
    throw 'Analysis: unreachable(${node.runtimeType})';
  }

  bool visitArgumentList(ast.ArgumentList node) {
    var result = false;
    for (var e in node.arguments) {
      if (visit(e)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitCatchClause(ast.CatchClause node) {
    return maybeAdd(node, visit(node.body));
  }

  bool visitVariableDeclarationList(ast.VariableDeclarationList node) {
    var result = false;
    for (var d in node.variables) {
      if (visit(d)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitVariableDeclaration(ast.VariableDeclaration node) {
    names.add(node.name.name);
    if (node.initializer == null) return false;
    return maybeAdd(node, visit(node.initializer));
  }

  // ---- Statements ----
  bool visitAssertStatement(ast.AssertStatement node) {
    return maybeAdd(node, visit(node.condition));
  }

  bool visitBlock(ast.Block node) {
    var result = false;
    for (var s in node.statements) {
      if (visit(s)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitBreakStatement(ast.BreakStatement node) {
    return false;
  }

  bool visitContinueStatement(ast.ContinueStatement node) {
    return false;
  }

  bool visitDoStatement(ast.DoStatement node) {
    var result = visit(node.body);
    return maybeAdd(node, visit(node.condition) || result);
  }

  bool visitEmptyStatement(ast.EmptyStatement node) {
    return false;
  }

  bool visitExpressionStatement(ast.ExpressionStatement node) {
    return maybeAdd(node, visit(node.expression));
  }

  bool visitForEachStatement(ast.ForEachStatement node) {
    if (node.identifier != null) {
      names.add(node.identifier.name);
    } else {
      assert(node.loopVariable != null);
      names.add(node.loopVariable.identifier.name);
    }
    var result = visit(node.iterator);
    return maybeAdd(node, visit(node.body) || result);
  }

  bool visitForStatement(ast.ForStatement node) {
    var result = false;
    if (node.variables != null) {
      result = visit(node.variables);
    } else if (node.initialization != null) {
      result = visit(node.initialization);
    }
    if (node.condition != null) {
      if (visit(node.condition)) result = true;
    }
    if (visit(node.body)) result = true;
    if (node.updaters != null) {
      for (var e in node.updaters) {
        if (visit(e)) result = true;
      }
    }
    return maybeAdd(node, result);
  }

  bool visitFunctionDeclarationStatement(
      ast.FunctionDeclarationStatement node) {
    return false;
  }

  bool visitIfStatement(ast.IfStatement node) {
    var result = visit(node.condition);
    if (visit(node.thenStatement)) result = true;
    if (node.elseStatement != null) {
      if (visit(node.elseStatement)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitLabeledStatement(ast.LabeledStatement node) {
    labels[node.statement] = node.labels;
    return maybeAdd(node, visit(node.statement));
  }

  bool visitRethrowExpression(ast.RethrowExpression node) {
    return false;
  }

  bool visitReturnStatement(ast.ReturnStatement node) {
    if (node.expression == null) return false;
    return maybeAdd(node, visit(node.expression));
  }

  bool visitSwitchCase(ast.SwitchCase node) {
    var result = visit(node.expression);
    for (var s in node.statements) {
      if (visit(s)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitSwitchDefault(ast.SwitchDefault node) {
    var result = false;
    for (var s in node.statements) {
      if (visit(s)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitSwitchStatement(ast.SwitchStatement node) {
    var result = visit(node.expression);
    for (var m in node.members) {
      if (visit(m)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitTryStatement(ast.TryStatement node) {
    var result = visit(node.body);
    for (var clause in node.catchClauses) {
      if (visit(clause)) result = true;
    }
    if (node.finallyBlock != null) {
      if (visit(node.finallyBlock)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitVariableDeclarationStatement(
        ast.VariableDeclarationStatement node) {
    return maybeAdd(node, visit(node.variables));
  }

  bool visitWhileStatement(ast.WhileStatement node) {
    var result = visit(node.condition);
    return maybeAdd(node, visit(node.body) || result);
  }

  bool visitYieldStatement(ast.YieldStatement node) {
    return maybeAdd(node, visit(node.expression));
  }

  // ---- Expressions ----
  bool visitExpression(ast.Expression node) {
    throw 'Analysis: unimplemented(${node.runtimeType})';
  }

  bool visitAdjacentStrings(ast.AdjacentStrings node) {
    var result = false;
    for (var s in node.strings) {
      if (visit(s)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitAsExpression(ast.AsExpression node) {
    return maybeAdd(node, visit(node.expression));
  }

  bool visitAssignmentExpression(ast.AssignmentExpression node) {
    var result = visit(node.leftHandSide);
    return maybeAdd(node, visit(node.rightHandSide) || result);
  }

  bool visitAwaitExpression(ast.AwaitExpression node) {
    visit(node.expression);
    awaits.add(node);
    return true;
  }

  bool visitBinaryExpression(ast.BinaryExpression node) {
    var result = visit(node.leftOperand);
    return maybeAdd(node, visit(node.rightOperand) || result);
  }

  bool visitBooleanLiteral(ast.BooleanLiteral node) {
    return false;
  }

  bool visitCascadeExpression(ast.CascadeExpression node) {
    var result = visit(node.target);
    for (var s in node.cascadeSections) {
      if (visit(s)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitConditionalExpression(ast.ConditionalExpression node) {
    var result = visit(node.condition);
    if (visit(node.thenExpression)) result = true;
    return maybeAdd(node, visit(node.elseExpression) || result);
  }

  bool visitDoubleLiteral(ast.DoubleLiteral node) {
    return false;
  }

  bool visitFunctionExpression(ast.FunctionExpression node) {
    return false;
  }

  bool visitIndexExpression(ast.IndexExpression node) {
    var result = (node.target != null) && visit(node.target);
    return maybeAdd(node, visit(node.index) || result);
  }

  bool visitInstanceCreationExpression(ast.InstanceCreationExpression node) {
    return maybeAdd(node, visit(node.argumentList));
  }

  bool visitIntegerLiteral(ast.IntegerLiteral node) {
    return false;
  }

  bool visitIsExpression(ast.IsExpression node) {
    return maybeAdd(node, visit(node.expression));
  }

  bool visitFunctionExpressionInvocation(
      ast.FunctionExpressionInvocation node) {
    var result = visit(node.function);
    return maybeAdd(node, visit(node.argumentList) || result);
  }

  bool visitListLiteral(ast.ListLiteral node) {
    var result = false;
    for (var e in node.elements) {
      if (visit(e)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitMapLiteral(ast.MapLiteral node) {
    var result = false;
    for (var entry in node.entries) {
      if (visit(entry)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitMapLiteralEntry(ast.MapLiteralEntry node) {
    var result = visit(node.key);
    return maybeAdd(node, visit(node.value) || result);
  }

  bool visitMethodInvocation(ast.MethodInvocation node) {
    var result = node.target != null && visit(node.target);
    return maybeAdd(node, visit(node.argumentList) || result);
  }

  bool visitNamedExpression(ast.NamedExpression node) {
    return maybeAdd(node, visit(node.expression));
  }

  bool visitNullLiteral(ast.NullLiteral node) {
    return false;
  }

  bool visitParenthesizedExpression(ast.ParenthesizedExpression node) {
    return maybeAdd(node, visit(node.expression));
  }

  bool visitPostfixExpression(ast.PostfixExpression node) {
    return maybeAdd(node, visit(node.operand));
  }

  bool visitPrefixedIdentifier(ast.PrefixedIdentifier node) {
    names.add(node.prefix.name);
    names.add(node.identifier.name);
    return false;
  }

  bool visitPrefixExpression(ast.PrefixExpression node) {
    return maybeAdd(node, visit(node.operand));
  }

  bool visitPropertyAccess(ast.PropertyAccess node) {
    return maybeAdd(node, node.target != null && visit(node.target));
  }

  bool visitSimpleStringLiteral(ast.SimpleStringLiteral node) {
    return false;
  }

  bool visitSimpleIdentifier(ast.SimpleIdentifier node) {
    names.add(node.name);
    return false;
  }

  bool visitSuperExpression(ast.SuperExpression node) {
    return false;
  }

  bool visitThisExpression(ast.ThisExpression node) {
    return false;
  }

  bool visitInterpolationExpression(ast.InterpolationExpression node) {
    return maybeAdd(node, visit(node.expression));
  }

  bool visitInterpolationString(ast.InterpolationString node) {
    return false;
  }

  bool visitStringInterpolation(ast.StringInterpolation node) {
    var result = false;
    for (var elt in node.elements) {
      if (visit(elt)) result = true;
    }
    return maybeAdd(node, result);
  }

  bool visitSymbolLiteral(ast.SymbolLiteral node) {
    return false;
  }

  bool visitThrowExpression(ast.ThrowExpression node) {
    return maybeAdd(node, visit(node.expression));
  }
}

ast.VariableDeclarationStatement variableDeclaration(
    String name, ast.Expression initializer) {
  return make.variableDeclarationStatement(scanner.Keyword.FINAL,
          [make.variableDeclaration(name, initializer)]);
}

// Information needed to generate a break or continue from a loop or labeled
// statement.  Needed is:
//
// * A list of labels (statements can have multiple labels), used to
//   search for the target given a label of a break or continue.
// * An expression denoting a zero-argument function to call for the jump.
// * An optional loop trampoline name.  For an await in a loop, the .then
//   callback must reestablish a loop on the stack to handle synchronous
//   looping without a stack overflow, via a trampoline.
class JumpTarget {
  final List<ast.Label> labels;
  final ast.Expression expression;
  final String trampolineName;

  JumpTarget(this.labels, this.expression, [this.trampolineName]);
}

abstract class ErrorContinuation {
  ast.Expression reify();
  ast.Expression apply(String exceptionName, String stackTraceName);
}

class NamedErrorContinuation extends ErrorContinuation {
  final ast.Identifier name;

  NamedErrorContinuation(String first, [String second])
      : name = make.identifier(first, second);

  ast.Expression reify() {
    return name;
  }

  ast.Expression apply(String exceptionName, String stackTraceName) {
    return make.functionInvocation(name,
        [make.identifier(exceptionName), make.identifier(stackTraceName)]);
  }
}

class AnonymousErrorContinuation extends ErrorContinuation {
  final AsyncTransformer owner;
  final applyFunction;

  AnonymousErrorContinuation(AsyncTransformer this.owner,
      ast.Expression this.applyFunction(String e, String s));

  ast.Expression reify() {
    var exceptionName = owner.newName('e');
    var stackTraceName = owner.newName('s');
    return make.functionExpression([exceptionName, stackTraceName],
        applyFunction(exceptionName, stackTraceName));
  }

  ast.Expression apply(String exceptionName, String stackTraceName) {
    return applyFunction(exceptionName, stackTraceName);
  }
}

class AsyncTransformer extends ast.AstVisitor {
  Set<ast.AstNode> awaits;
  Map<ast.Statement, List<ast.Label>> labels;
  Set<String> names;

  ast.Block currentBlock;

  // Stacks of targets for break and continue.
  List<JumpTarget> breakTargets;
  List<JumpTarget> continueTargets;

  // Inside a catch block, `rethrow` throws the current exception.  The
  // translation maintains a current exception and stack trace when inside a
  // catch block.  They are null outside a catch block.
  String currentExceptionName;
  String currentStackTraceName;

  // Inside an asynchronous for loop, the translation maintains the name of
  // the current stream's StreamController.  When not inside an asynchronous
  // for loop, it is null.
  String currentStream;

  visit(ast.AstNode node) => node.accept(this);

  Map<String, int> nameCounters;

  String newName(String base) {
    if (!nameCounters.containsKey(base)) nameCounters[base] = 0;
    var name;
    do {
      name = '$base${nameCounters[base]++}';
    } while (names.contains(name));
    return name;
  }

  void reset(Analysis analysis) {
    nameCounters = <String, int>{};
    currentBlock = make.emptyBlock();
    breakTargets = <JumpTarget>[];
    continueTargets = <JumpTarget>[];
    currentExceptionName = null;
    currentStackTraceName = null;
    currentStream = null;
    awaits = analysis.awaits;
    labels = analysis.labels;
    names = analysis.names;
  }

  /// Insert a declaration with initial value [expr] in [currentBlock] and
  /// return the fresh name.
  ///
  /// No declaration is added if the expression is already a value and [force]
  /// is false.
  ast.Expression addTempDeclaration(ast.Expression expr) {
    if (expr is ast.Literal && expr is! ast.TypedLiteral) {
      return expr;
    }
    var name = newName('v');
    addStatement(variableDeclaration(name, expr));
    return make.identifier(name);
  }

  void addStatement(ast.AstNode node) {
    if (node is ast.Statement) {
      currentBlock.statements.add(node);
    } else {
      assert(node is ast.Expression);
      currentBlock.statements.add(make.expressionStatement(node));
    }
  }

  ast.FunctionExpression reifyExpressionCont(f, baseName) {
    var savedBlock = currentBlock;
    var bodyBlock = currentBlock = make.emptyBlock();
    String name = newName(baseName);
    f(make.identifier(name));
    currentBlock = savedBlock;
    return make.functionExpression([name], bodyBlock);
  }

  // For finally blocks, the return continuation is wrapped in a thunk.
  ast.FunctionExpression abstractReturnCont(r, expr) {
    var v = addTempDeclaration(expr);
    var savedBlock = currentBlock;
    var bodyBlock = currentBlock = make.emptyBlock();
    addStatement(make.returnStatement(r(v)));
    currentBlock = savedBlock;
    return make.functionExpression([], bodyBlock);
  }

  // ---- CompilationUnit ----
  visitCompilationUnit(ast.CompilationUnit node) {
    // TODO(kmillikin): import 'dart:async' if necessary.
    return new ast.CompilationUnit(
        node.beginToken,
        node.scriptTag,
        node.directives,
        node.declarations.map(visit).toList(),
        node.endToken);
  }

  // ---- CompilationUnitMembers ----
  visitClassDeclaration(ast.ClassDeclaration node) {
    return new ast.ClassDeclaration(
        node.documentationComment,
        node.metadata,
        node.abstractKeyword,
        node.classKeyword,
        node.name,
        node.typeParameters,
        node.extendsClause,
        node.withClause,
        node.implementsClause,
        node.leftBracket,
        node.members.map(visit).toList(),
        node.rightBracket);
  }

  visitClassTypeAlias(ast.ClassTypeAlias node) {
    return node;
  }

  visitEnumDeclaration(ast.EnumDeclaration node) {
    return node;
  }

  visitFunctionDeclaration(ast.FunctionDeclaration node) {
    node.functionExpression.body = visit(node.functionExpression.body);
    return node;
  }

  visitFunctionTypeAlias(ast.FunctionTypeAlias node) {
    return node;
  }

  visitTopLevelVariableDeclaration(ast.TopLevelVariableDeclaration node) {
    return node;
  }

  // ---- ClassMembers ----
  visitConstructorDeclaration(ast.ConstructorDeclaration node) {
    return node;
  }

  visitFieldDeclaration(ast.FieldDeclaration node) {
    return node;
  }

  visitMethodDeclaration(ast.MethodDeclaration node) {
    node.body = visit(node.body);
    return node;
  }

  // ---- FunctionBodies ----
  visitBlockFunctionBody(ast.BlockFunctionBody node) {
    if (node.isGenerator) {
      throw 'Transfomer: unsupported generator function.';
    }
    if (node.isSynchronous) {
      new SyncTransformer().visit(node);
      return node;
    }

    Analysis analysis = new Analysis();
    analysis.visit(node.block);
    reset(analysis);

    var completerName = newName('completer');
    visit(node.block)((v) {
      addStatement(make.methodInvocation(make.identifier(completerName),
          'complete', [v]));
    }, new NamedErrorContinuation(completerName, 'completeError'), () {
      addStatement(make.methodInvocation(make.identifier(completerName),
          'complete', []));
    });

    return make.functionBody(make.block(
        [make.variableDeclarationStatement(scanner.Keyword.FINAL,
             [make.variableDeclaration(completerName,
                  make.newInstance(make.identifier('Completer'), []))]),
         make.functionInvocation('scheduleMicrotask',
             [make.functionExpression([],
                  make.tryStatement(currentBlock,
                      [make.catchClause(null, 'e', 's',
                           make.block(
                               [make.methodInvocation(
                                    make.identifier(completerName),
                                    'completeError',
                                    [make.identifier('e'),
                                     make.identifier('s')])]))]))]),
         make.returnStatement(make.propertyAccess(
             make.identifier(completerName), 'future'))]));
  }

  visitEmptyFunctionBody(ast.EmptyFunctionBody node) {
    return node;
  }

  visitExpressionFunctionBody(ast.ExpressionFunctionBody node) {
    var body = make.functionBody(make.returnStatement(node.expression));
    (body as ast.BlockFunctionBody).keyword = node.keyword;
    return visit(body);
  }

  visitNativeFunctionBody(ast.NativeFunctionBody node) {
    return node;
  }

  // ---- Statements ----
  unimplemented(ast.AstNode node) => throw 'Unimplemented(${node.runtimeType})';

  visitAssertStatement(ast.AssertStatement node) => (rk, ek, sk) {
    return visit(node.condition)(ek, (cond) {
      addStatement(make.assertStatement(cond));
      return sk();
    });
  };

  _translateStatementList(ast.NodeList<ast.Statement> list, rk, ek, sk) {
    var cont = sk;
    for (var stmt in list.reversed) {
      var nextCont = cont;
      cont = () => visit(stmt)(rk, ek, nextCont);
    }
    return cont();
  }

  visitBlock(ast.Block node) => (rk, ek, sk) {
    return _translateStatementList(node.statements, rk, ek, sk);
  };

  List<JumpTarget> _addBreakTarget(List<ast.Label> labels,
      ast.Expression expression) {
    return new List.from(breakTargets)
        ..add(new JumpTarget(labels, expression));
  }

  List<JumpTarget> _addContinueTarget(List<ast.Label> labels,
      ast.Expression expression, [String trampolineName]) {
    return new List.from(continueTargets)
        ..add(new JumpTarget(labels, expression, trampolineName));
  }

  JumpTarget _findJumpTarget(node, List<JumpTarget> targets) {
    if (node.label == null) {
      return targets.last;
    }
    for (var target in targets.reversed) {
      if (target.labels == null) continue;
      for (var label in target.labels) {
        if (label.label.name == node.label.name) return target;
      }
    }
    throw "Could not find target for '$node'";
  }

  visitBreakStatement(ast.BreakStatement node) => (rk, ek, sk) {
    var target = _findJumpTarget(node, breakTargets);
    addStatement(make.functionInvocation(target.expression));
  };

  visitContinueStatement(ast.ContinueStatement node) => (rk, ek, sk) {
    var target = _findJumpTarget(node, continueTargets);
    addStatement(make.functionInvocation(target.expression));
  };

  // The template of the loop trampoline loop.  A trampoline is used to avoid
  // stack overflow for loops that contain await but have a synchronous path
  // through the loop.
  //
  // If `init` is the initial value of the trampoline function, then the
  // trampoline loop is:
  //
  // trampoline = init;
  // do trampoline(); while (tramploline != null);
  void _addTrampoline(String trampolineName, ast.Expression initialValue) {
    addStatement(make.assignmentExpression(make.identifier(trampolineName),
        initialValue));
    addStatement(make.doStatement(
        make.expressionStatement(make.functionInvocation(trampolineName)),
        make.binaryExpression(make.identifier(trampolineName),
            scanner.TokenType.BANG_EQ, make.nullLiteral())));
  }

  // [[do S1 while (E); S2]] =
  //     break_() { [[S2]] }
  //     var trampoline;
  //     loop() {
  //         trampoline = null;
  //         continue_() {
  //             trampoline = null;
  //             final v = [[E]];
  //             if (v) {
  //                 loop();
  //             } else {
  //                 break_();
  //             }
  //         }
  //         [[S1]]
  //         trampoline = continue_;
  //     }
  //     trampoline = loop;
  //     do trampoline(); while (trampoline != null);
  visitDoStatement(ast.DoStatement node) => (rk, ek, sk) {
    var breakName = newName('break');
    var continueName = newName('continue');
    var loopName = newName('loop');
    var trampolineName = newName('trampoline');

    var savedBlock = currentBlock;
    var breakBlock = currentBlock = make.emptyBlock();
    sk();

    // Though break and continue cannot occur in the loop condition, the
    // targets are added here.  An await in the condition uses the presence
    // of the continue target to know it is in the loop.  Break is
    // added so that the two stacks of targets are handled uniformly.
    var savedBreakTargets = breakTargets;
    var savedContinueTargets = continueTargets;
    breakTargets = _addBreakTarget(labels[node], make.identifier(breakName));
    continueTargets = _addContinueTarget(labels[node],
        make.identifier(continueName), trampolineName);
    var continueBlock = currentBlock = make.emptyBlock();
    addStatement(make.assignmentExpression(make.identifier(trampolineName),
        make.nullLiteral()));
    visit(node.condition)(ek, (expr) {
      addStatement(make.ifStatement(
          expr,
          make.block([make.functionInvocation(loopName)]),
          make.block([make.functionInvocation(breakName)])));
    });

    var loopBlock = currentBlock = make.emptyBlock();
    addStatement(make.assignmentExpression(make.identifier(trampolineName),
        make.nullLiteral()));
    addStatement(
        make.functionDeclarationStatement(continueName, [], continueBlock));
    visit(node.body)(rk, ek, () {
      _addTrampoline(trampolineName, make.identifier(continueName));
    });

    breakTargets = savedBreakTargets;
    continueTargets = savedContinueTargets;
    currentBlock = savedBlock;
    addStatement(
        make.functionDeclarationStatement(breakName, [], breakBlock));
    addStatement(
        make.variableDeclarationStatement(scanner.Keyword.VAR,
            [make.variableDeclaration(trampolineName)]));
    addStatement(
        make.functionDeclarationStatement(loopName, [], loopBlock));
    _addTrampoline(trampolineName, make.identifier(loopName));
  };

  visitEmptyStatement(ast.EmptyStatement node) => (rk, ek, sk) {
    return sk();
  };

  visitExpressionStatement(ast.ExpressionStatement node) => (rk, ek, sk) {
    return visit(node.expression)(ek, (expr) {
      addStatement(expr);
      return sk();
    });
  };

  // Expand the syntactic sugar of a for-in loop according to the translation
  // in the spec.
  _translateSynchronousForEach(ast.ForEachStatement node) {
    var stmt = make.emptyBlock();
    var it = newName('it');
    stmt.statements.add(
        make.variableDeclarationStatement(
            scanner.Keyword.VAR,
            [make.variableDeclaration(it,
                 make.propertyAccess(node.iterator, 'iterator'))]));
    var body;
    if (node.identifier != null) {
      body = make.block(
          [make.assignmentExpression(
               node.identifier,
               make.propertyAccess(make.identifier(it), 'current')),
           node.body]);
    } else {
      assert(node.loopVariable != null);
      body = make.block(
          [make.variableDeclarationStatement(
              make.keyword(node.loopVariable.keyword),
              [make.variableDeclaration(
                   node.loopVariable.identifier.name,
                   make.propertyAccess(make.identifier(it), 'current'))],
              node.loopVariable.type),
           node.body]);
    }
    stmt.statements.add(make.whileStatement(
        make.methodInvocation(make.identifier(it), 'moveNext', []),
        body));
    return stmt;
  }

  // The asynchronous loop `await for (T X in E) S1; S2;` is translated
  // with respect to an outer stream `outer` as:
  //
  // done() {
  //   outer.resume();
  //   [[S2]]
  // }
  // finally_(cont) {
  //   try {
  //     new Future.value(stream.cancel()).then(cont);
  //   } catch (ex, st) {
  //     ek(ex, st);
  //   }
  // }
  // catch_(ex, st) {
  //   finally_(() => ek(ex, st));
  // }
  // outer.pause();
  // var stream;
  // stream = [[E]].listen((v) {
  //     T X = v;
  //     [[S1]]
  // }, onError: catch_, onDone: done);
  visitForEachStatement(ast.ForEachStatement node) {
    if (node.awaitKeyword == null) {
      var stmt = _translateSynchronousForEach(node);
      return visitBlock(stmt);
    }
    return (rk, ek, sk) {
      return visit(node.iterator)(ek, (expr) {
        var savedBlock = currentBlock;
        var doneBlock = currentBlock = make.emptyBlock();
        var doneName = newName('done');
        if (currentStream != null) {
          addStatement(make.methodInvocation(
              make.identifier(currentStream), 'resume', []));
        }
        sk();

        var finallyBlock = currentBlock = make.emptyBlock();
        var finallyName = newName('finally');
        var finallyContName = newName('cont');
        var exceptionName = newName('e');
        var stackTraceName = newName('s');
        var streamName = newName('stream');
        addStatement(make.tryStatement(make.block(
            [make.methodInvocation(
                 make.newInstance(make.identifier('Future', 'value'),
                     [make.methodInvocation(
                          make.identifier(streamName), 'cancel', [])]),
                 'then',
                 [make.identifier(finallyContName)])]),
            [make.catchClause(null, exceptionName, stackTraceName,
                make.block([ek.apply(exceptionName, stackTraceName)]))]));

        var catchBlock = currentBlock = make.emptyBlock();
        var catchName = newName('catch');
        addStatement(make.functionInvocation(finallyName,
            [make.functionExpression([],
                 ek.apply(exceptionName, stackTraceName))]));

        var listenBlock = currentBlock = make.emptyBlock();
        var parameter = newName('x');
        if (node.identifier != null) {
          addStatement(make.assignmentExpression(
              node.identifier, make.identifier(parameter)));
        } else {
          assert(node.loopVariable != null);
          addStatement(make.variableDeclarationStatement(
              make.keyword(node.loopVariable.keyword),
              [make.variableDeclaration(
                   node.loopVariable.identifier.name,
                   make.identifier(parameter))],
              node.loopVariable.type));
        }

        var savedBreakTargets = breakTargets;
        var savedContinueTargets = continueTargets;
        var savedStream = currentStream;
        breakTargets =
            breakTargets.map(_finallyBreakTarget(finallyName)).toList();
        continueTargets =
            continueTargets.map(_finallyContinueTarget(finallyName)).toList();
        currentStream = streamName;
        visit(node.body)((v) {
          v = addTempDeclaration(v);
          var savedBlock = currentBlock;
          var returnBlock = currentBlock = make.emptyBlock();
          rk(v);
          currentBlock = savedBlock;
          addStatement(make.functionInvocation(finallyName,
              [make.functionExpression([], returnBlock)]));
        }, new NamedErrorContinuation(catchName), () {});


        breakTargets = savedBreakTargets;
        continueTargets = savedContinueTargets;
        currentStream = savedStream;
        currentBlock = savedBlock;
        addStatement(
            make.functionDeclarationStatement(doneName, [], doneBlock));
        addStatement(make.variableDeclarationStatement(
            scanner.Keyword.VAR, [make.variableDeclaration(streamName)]));
        addStatement(make.functionDeclarationStatement(finallyName,
            [finallyContName], finallyBlock));
        addStatement(make.functionDeclarationStatement(catchName,
            [exceptionName, stackTraceName], catchBlock));
        if (currentStream != null) {
          addStatement(make.methodInvocation(
              make.identifier(currentStream), 'pause', []));
        }
        addStatement(make.assignmentExpression(
            make.identifier(streamName),
            make.methodInvocation(expr, 'listen',
                [make.functionExpression([parameter], listenBlock),
                 make.namedExpression('onError', make.identifier(catchName)),
                 make.namedExpression('onDone', make.identifier(doneName))])));
      });
    };
  }

  _translateForUpdaters(List<ast.Expression> exprs, ek, sk) {
    var cont = sk;
    for (var expr in exprs.reversed) {
      var nextCont = cont;
      cont = () {
        return visit(expr)(ek, (expr) {
          addStatement(expr);
          return nextCont();
        });
      };
     }
     return cont();
   }

  _translateForDeclarations(List<ast.VariableDeclaration> decls, ek, sk) {
    var exprs = [];
    var seenAwait = false;
    var cont = (e) {
      exprs.add(e);
      return sk(exprs);
    };
    for (var i = decls.length - 1; i >= 1; --i) {
      // Build the continuation for the i-1 initializer expression.
      var nextExpr = decls[i].initializer;
      if (nextExpr != null) {
        seenAwait = seenAwait || awaits.contains(nextExpr);
      }
      var nextCont = cont;
      var copiedSeenAwait = seenAwait;
      cont = (e) {
        if (copiedSeenAwait) e = addTempDeclaration(e);
        exprs.add(e);
        return (nextExpr == null)
            ? nextCont(make.nullLiteral())
            : visit(nextExpr)(ek, nextCont);
      };
    }
    var expr = decls.first.initializer;
    return (expr == null)
        ? cont(make.nullLiteral())
        : visit(expr)(ek, cont);
  }

  // The intializer and update parts are not really expressions and all of them
  // are optional.  Informally though, the translation is:
  // [[for (E1; E2; E3) S1; S2]] =
  //     break_() { [[S2]] }
  //     var trampoline;
  //     loop(x) {
  //         trampoline = null;
  //         continue_() {
  //             trampoline = null;
  //             [[E3]];
  //             loop(x);
  //         }
  //         final v = [[E2]];
  //         if (v) {
  //           [[S1]]
  //           trampoline = continue_;
  //         } else {
  //           break_();
  //         }
  //     }
  //     final v = [[E1]];
  //     trampoline = () => loop(v);
  //     do trampoline(); while (trampoline != null);
  visitForStatement(ast.ForStatement node) => (rk, ek, sk) {
    var breakName = newName('break');
    var continueName = newName('continue');
    var loopName = newName('loop');
    var trampolineName = newName('trampoline');

    var savedBlock = currentBlock;
    var breakBlock = currentBlock = make.emptyBlock();
    sk();

    var parameters;
    if (node.variables != null) {
      parameters = node.variables.variables.map((d) => d.name).toList();
    } else {
      parameters = <ast.SimpleIdentifier>[];
    }

    // Though break and continue cannot occur in the loop condition or
    // updaters, the targets are added here.  An await in the condition or
    // updaters uses the presence of the continue target to know it is in the
    // loop.  Break is added so that the two stacks of targets are handled
    // uniformly.
    var savedBreakTargets = breakTargets;
    var savedContinueTargets = continueTargets;
    breakTargets = _addBreakTarget(labels[node], make.identifier(breakName));
    continueTargets = _addContinueTarget(labels[node],
        make.identifier(continueName), trampolineName);
    var continueBlock = currentBlock = make.emptyBlock();
    addStatement(make.assignmentExpression(make.identifier(trampolineName),
        make.nullLiteral()));
    invokeLoop() {
      addStatement(make.functionInvocation(loopName, parameters));
    }
    if (node.updaters != null) {
      _translateForUpdaters(node.updaters, ek, invokeLoop);
    } else {
      invokeLoop();
    }

    var bodyBlock = currentBlock = make.emptyBlock();
    visit(node.body)(rk, ek, () {
      _addTrampoline(trampolineName, make.identifier(continueName));
    });

    var loopBlock = currentBlock = make.emptyBlock();
    addStatement(make.assignmentExpression(make.identifier(trampolineName),
        make.nullLiteral()));
    addStatement(
        make.functionDeclarationStatement(continueName, [], continueBlock));
    if (node.condition != null) {
      visit(node.condition)(ek, (expr) {
        addStatement(make.ifStatement(
          expr,
          bodyBlock,
          make.block([make.functionInvocation(breakName)])));
      });
    } else {
      addStatement(bodyBlock);
    }

    breakTargets = savedBreakTargets;
    continueTargets = savedContinueTargets;
    currentBlock = savedBlock;
    addStatement(
        make.functionDeclarationStatement(breakName, [], breakBlock));
    addStatement(
        make.variableDeclarationStatement(scanner.Keyword.VAR,
            [make.variableDeclaration(trampolineName)]));
    addStatement(make.functionDeclarationStatement(loopName,
        parameters.map((e) => e.name).toList(), loopBlock));
    if (node.variables != null) {
      assert(node.variables.variables.isNotEmpty);
      return _translateForDeclarations(node.variables.variables, ek, (args) {
        assert(args.length == parameters.length);
        _addTrampoline(trampolineName, make.functionExpression([],
            make.functionInvocation(loopName, args)));
      });
    } else if (node.initialization != null) {
      assert(parameters.isEmpty);
      return visit(node.initialization)(ek, (expr) {
        addStatement(expr);
        _addTrampoline(trampolineName, make.identifier(loopName));
      });
    } else {
      assert(parameters.isEmpty);
      _addTrampoline(trampolineName, make.identifier(loopName));
    }
  };

  visitFunctionDeclarationStatement(
      ast.FunctionDeclarationStatement node) => (rk, ek, sk) {
    var decl = new AsyncTransformer().visit(node.functionDeclaration);
    addStatement(new ast.FunctionDeclarationStatement(decl));
    return sk();
  };

  visitIfStatement(ast.IfStatement node) => (rk, ek, sk) {
    return visit(node.condition)(ek, (expr) {
      var savedBlock = currentBlock;
      var joinName = newName('join');
      var joinBlock = currentBlock = make.emptyBlock();
      sk();

      var cont = () {
        addStatement(make.functionInvocation(joinName));
      };
      var thenBlock = currentBlock = make.emptyBlock();
      visit(node.thenStatement)(rk, ek, cont);
      var elseBlock = currentBlock = make.emptyBlock();
      if (node.elseStatement != null) {
        visit(node.elseStatement)(rk, ek, cont);
      } else {
        cont();
      }

      currentBlock = savedBlock;
      addStatement(make.functionDeclarationStatement(joinName, [], joinBlock));
      addStatement(make.ifStatement(expr, thenBlock, elseBlock));
    });
  };

  bool _isLoop(ast.AstNode node) {
    return node is ast.DoStatement ||
        node is ast.ForEachStatement ||
        node is ast.ForStatement ||
        node is ast.WhileStatement;
  }

  visitLabeledStatement(ast.LabeledStatement node) {
    var stmt = node.statement;
    if (_isLoop(stmt) || stmt is ast.SwitchStatement) {
      return visit(stmt);
    }
    return (rk, ek, sk) {
      var breakName = newName('break');
      var savedBlock = currentBlock;
      var breakBlock = currentBlock = make.emptyBlock();
      sk();
      currentBlock = savedBlock;

      addStatement(
          make.functionDeclarationStatement(breakName, [], breakBlock));

      var savedBreakTargets = breakTargets;
      breakTargets = _addBreakTarget(labels[stmt], make.identifier(breakName));
      visit(stmt)(rk, ek, () {
        addStatement(make.functionInvocation(breakName));
      });
      breakTargets = savedBreakTargets;
    };
  }

  visitReturnStatement(ast.ReturnStatement node) => (rk, ek, sk) {
    return (node.expression == null)
        ? rk(make.nullLiteral())
        : visit(node.expression)(ek, rk);
  };

  visitSwitchStatement(ast.SwitchStatement node) => (rk, ek, sk) {
    return visit(node.expression)(ek, (expr) {
      var savedBlock = currentBlock;
      var breakBlock = currentBlock = make.emptyBlock();
      sk();

      currentBlock = savedBlock;
      var breakName = newName('break');
      addStatement(
          make.functionDeclarationStatement(breakName, [], breakBlock));

      // Generate a name per labeled case.  Since this is not a loop continue
      // there is no need to worry about trampolines.  To avoid reallocating
      // the continueTarget list in a loop, the targets are added manually
      // instead of using _addContinueTarget.
      var savedContinueTargets = continueTargets;
      continueTargets = new List.from(continueTargets);
      var continueNames = [];
      for (var member in node.members) {
        var labels = member.labels;
        if (labels.isNotEmpty) {
          var continueName = newName('continue');
          continueNames.add(continueName);
          continueTargets.add(new JumpTarget(member.labels,
              make.identifier(continueName)));
        }
      }

      // Translate the cases with bindings for the break and possible
      // continues.
      var savedBreakTargets = breakTargets;
      breakTargets = _addBreakTarget(labels[node], make.identifier(breakName));
      if (continueNames.isNotEmpty) {
        // Add declarations for mutable continue functions.
        addStatement(
            make.variableDeclarationStatement(scanner.Keyword.VAR,
                continueNames.map(make.variableDeclaration).toList()));

        // Translate the labeled cases as recursive functions.
        var index = 0;
        for (var member in node.members) {
          if (member.labels.isEmpty) continue;
          var savedBlock = currentBlock;
          var caseBlock = currentBlock = make.emptyBlock();
          _translateStatementList(member.statements, rk, ek, () {
            addStatement(make.functionInvocation(breakName));
          });
          currentBlock = savedBlock;
          addStatement(make.assignmentExpression(
              make.identifier(continueNames[index]),
              make.functionExpression([], caseBlock)));
          ++index;
        }
      }

      // Translate the unlabeled cases as blocks and the labeled cases as
      // calls to the corresponding continue function.
      savedBlock = currentBlock;
      var members = [];
      var index = 0;
      for (var member in node.members) {
        var bodyBlock;
        if (member.labels.isEmpty) {
          bodyBlock = currentBlock = make.emptyBlock();
          _translateStatementList(member.statements, rk, ek, () {
            addStatement(make.functionInvocation(breakName));
          });
        } else {
          bodyBlock =
              make.block([make.functionInvocation(continueNames[index])]);
          ++index;
        }
        bodyBlock.statements.add(make.breakStatement());
        if (member is ast.SwitchDefault) {
          members.add(make.switchCase(null, bodyBlock.statements));
        } else {
          members.add(make.switchCase((member as ast.SwitchCase).expression,
              bodyBlock.statements));
        }
      }
      breakTargets = savedBreakTargets;
      continueTargets = savedContinueTargets;
      currentBlock = savedBlock;
      addStatement(make.switchStatement(expr, members));
    });
  };

  _translateCatchClauses(List<ast.CatchClause> clauses, rk, ek, sk) {
    var savedExceptionName = currentExceptionName;
    var savedStackTraceName = currentStackTraceName;
    var catchName = newName('catch');
    var exceptionName, stackTraceName, catchBlock;
    if (clauses.isEmpty) {
      exceptionName = currentExceptionName = newName('e');
      stackTraceName = currentStackTraceName = newName('s');
      catchBlock = make.block([ek.apply(exceptionName, stackTraceName)]);
    } else {
      // The exception and stack trace parameters do not necessarily have the
      // same name for all clauses.  If there is only one clause, choose those
      // names.  Otherwise, choose fresh names to avoid shadowing anything.
      if (clauses.length == 1) {
        var only = clauses.first;
        exceptionName = currentExceptionName =
            only.exceptionParameter == null
                ? newName('e')
                : only.exceptionParameter.name;
        stackTraceName = currentStackTraceName =
            only.stackTraceParameter == null
                ? newName('s')
                : only.stackTraceParameter.name;
      } else {
        exceptionName = currentExceptionName = newName('e');
        stackTraceName = currentStackTraceName = newName('s');
      }
      // Build a chain of if/else statements nested in the else blocks.
      // Construct them in reverse with catchBlock as the accumulator.  If a
      // clause is unconditional, it will orphan the previous clauses.  Base
      // case (the final else clause) is to rethrow the exception.
      catchBlock =
          make.block([ek.apply(exceptionName, stackTraceName)]);
      var savedBlock = currentBlock;
      for (var clause in clauses.reversed) {
        var bodyBlock = currentBlock = make.emptyBlock();
        if (clause.exceptionParameter != null &&
            clause.exceptionParameter.name != exceptionName) {
          addStatement(make.assignmentExpression(clause.exceptionParameter,
              make.identifier(exceptionName)));
        }
        if (clause.stackTraceParameter != null &&
            clause.stackTraceParameter.name != stackTraceName) {
          addStatement(make.assignmentExpression(clause.stackTraceParameter,
              make.identifier(stackTraceName)));
        }
        visit(clause.body)(rk, ek, sk);
        if (clause.onKeyword == null) {
          catchBlock = bodyBlock;
        } else {
          catchBlock = make.block(
              [make.ifStatement(
                   make.isExpression(make.identifier(exceptionName), false,
                       clause.exceptionType),
                   bodyBlock,
                   catchBlock)]);
        }
      }

      currentBlock = savedBlock;
      // Entering the catch block from the try block is one of two places
      // where we jump out of a place to one with a different handler (the other
      // is entering the finally block from the try block of try/catch/finally).
      // We need to have an appropriate exception handler in place for catching
      // synchronous exceptions.
      catchBlock = make.tryStatement(catchBlock,
          [make.catchClause(null, exceptionName, stackTraceName,
               make.block([ek.apply(exceptionName, stackTraceName)]))]);
    }
    currentExceptionName = savedExceptionName;
    currentStackTraceName = savedStackTraceName;
    addStatement(make.functionDeclarationStatement(catchName,
        [exceptionName, stackTraceName], catchBlock));
    return catchName;
  }



  _finallyBreakTarget(String finallyName) => (JumpTarget target) {
    return new JumpTarget(target.labels,
        make.parenthesizedExpression(
            make.functionExpression([],
                make.functionInvocation(finallyName,
                    [target.expression]))));
  };

  _finallyContinueTarget(String finallyName) => (JumpTarget target) {
    if (target.trampolineName == null) {
      return _finallyBreakTarget(finallyName)(target);
    }
    return new JumpTarget(target.labels,
        make.parenthesizedExpression(
            make.functionExpression([],
                make.functionInvocation(finallyName,
                    [make.functionExpression([], make.block(
                         [make.assignmentExpression(
                              make.identifier(target.trampolineName),
                              target.expression)]))]))));
  };

  visitTryStatement(ast.TryStatement node) => (rk, ek, sk) {
    var savedBlock = currentBlock;
    var joinName = newName('join');
    var joinBlock = currentBlock = make.emptyBlock();
    sk();

    var savedBreakTargets = breakTargets;
    var savedContinueTargets = continueTargets;
    var finallyName, finallyContName, finallyBlock;
    if (node.finallyBlock != null) {
      finallyName = newName('finally');
      finallyContName = newName('cont');
      finallyBlock = currentBlock = make.emptyBlock();
      visit(node.finallyBlock)(rk, ek, () {
        addStatement(make.functionInvocation(finallyContName));
      });
      // Entering the finally block from the try block of a try/catch/finally
      // is one of two places where we jump out of a place to one with a
      // different handler (the other is entering the catch block from the try
      // block.  We need to have an appropriate exception handler in place for
      // catching synchronous exceptions.
      var exceptionName = newName('e');
      var stackTraceName = newName('s');
      if (node.catchClauses.isNotEmpty) {
        finallyBlock = make.tryStatement(finallyBlock,
            [make.catchClause(null, exceptionName, stackTraceName,
                 make.block([ek.apply(exceptionName, stackTraceName)]))]);
      }

      breakTargets =
          breakTargets.map(_finallyBreakTarget(finallyName)).toList();
      continueTargets =
          continueTargets.map(_finallyContinueTarget(finallyName)).toList();
      var ret = rk;
      rk = (v) {
        v = addTempDeclaration(v);
        var savedBlock = currentBlock;
        var returnBlock = currentBlock = make.emptyBlock();
        ret(v);
        currentBlock = savedBlock;
        addStatement(make.functionInvocation(finallyName,
            [make.functionExpression([], returnBlock)]));
      };
      var err = ek;
      ek = new AnonymousErrorContinuation (this, (e, s) {
        return make.functionInvocation(finallyName,
            [make.functionExpression([], err.apply(e, s))]);
      });
      sk = () {
        addStatement(make.functionInvocation(finallyName,
            [make.identifier(joinName)]));
      };
    } else {
      sk = () {
        addStatement(make.functionInvocation(joinName));
      };
    }

    currentBlock = savedBlock;
    addStatement(make.functionDeclarationStatement(joinName, [], joinBlock));
    if (finallyBlock != null) {
      addStatement(make.functionDeclarationStatement(
          finallyName, [finallyContName], finallyBlock));
    }
    var catchName = _translateCatchClauses(node.catchClauses, rk, ek, sk);

    var tryBlock = currentBlock = make.emptyBlock();
    ek = new NamedErrorContinuation(catchName);
    visit(node.body)(rk, ek, sk);

    currentBlock = savedBlock;
    breakTargets = savedBreakTargets;
    continueTargets = savedContinueTargets;

    var exceptionName = newName('e');
    var stackTraceName = newName('s');
    var catchBlock = make.block([ek.apply(exceptionName, stackTraceName)]);
    addStatement(make.tryStatement(tryBlock,
        [make.catchClause(null, exceptionName, stackTraceName, catchBlock)]));
  };

  _translateDeclarationList(scanner.Keyword keyword, ast.TypeName type,
      ast.VariableDeclarationList node, ek, sk) {
    translateDecl(ast.VariableDeclaration decl, ek, sk) {
      if (decl.initializer == null) {
        return sk(decl);
      } else {
        return visit(decl.initializer)(ek, (expr) {
          return sk(make.variableDeclaration(decl.name.name, expr));
        });
      }
    }

    var decls = [];
    // The continuation for the last declaration.
    var cont = (decl) {
      decls.add(decl);
      return sk(decls);
    };
    for (var i = node.variables.length - 1; i >= 1; --i) {
      var nextCont = cont;
      // The continuation for the i-1 declaration.
      cont = (decl) {
        decls.add(decl);
        var nextDecl = node.variables[i];
        if (awaits.contains(nextDecl)) {
          _residualizeDeclarationList(keyword, type, decls);
          decls.clear();
        }
        translateDecl(nextDecl, ek, nextCont);
      };
    }
    translateDecl(node.variables.first, ek, cont);
  }

  void _residualizeDeclarationList(scanner.Keyword keyword, ast.TypeName type,
      List<ast.VariableDeclaration> decls) {
    if (decls.isEmpty) return;
    addStatement(make.variableDeclarationStatement(keyword, decls, type));
  }

  visitVariableDeclarationStatement(
      ast.VariableDeclarationStatement node) => (rk, ek, sk) {
    var keyword = make.keyword(node.variables.keyword);
    var type = node.variables.type;
    return _translateDeclarationList(keyword, type, node.variables, ek,
        (decls) {
          _residualizeDeclarationList(keyword, type, decls);
          return sk();
        });
  };

  // [[while (E) S1; S2]] =
  //     break_() { [[S2]] }
  //     var trampoline;
  //     continue_() {
  //         trampoline = null;
  //         final v = [[E]];
  //         if (v) {
  //             [[S1]];
  //             trampoline = continue_;
  //         } else {
  //             break_();
  //         }
  //     }
  //     trampoline = continue_;
  //     do trampoline(); while (trampoline != null);
  visitWhileStatement(ast.WhileStatement node) => (rk, ek, sk) {
    var breakName = newName('break');
    var continueName = newName('continue');
    var trampolineName = newName('trampoline');

    var savedBlock = currentBlock;
    var breakBlock = currentBlock = make.emptyBlock();
    sk();

    // Though break and continue cannot occur in the loop condition, the
    // targets are added here.  An await in the condition is like a break so
    // the break target should be in scope for the condition.  Continue is
    // set so that the two stacks of targets are handled uniformly.
    var savedBreakTargets = breakTargets;
    var savedContinueTargets = continueTargets;
    breakTargets = _addBreakTarget(labels[node], make.identifier(breakName));
    continueTargets = _addContinueTarget(labels[node],
        make.identifier(continueName), trampolineName);
    var continueBlock = currentBlock = make.emptyBlock();
    addStatement(make.assignmentExpression(make.identifier(trampolineName),
        make.nullLiteral()));
    visit(node.condition)(ek, (expr) {
      var savedBlock = currentBlock;
      var bodyBlock = currentBlock = make.emptyBlock();
      visit(node.body)(rk, ek, () {
        _addTrampoline(trampolineName, make.identifier(continueName));
      });

      currentBlock = savedBlock;
      addStatement(make.ifStatement(
        expr,
        bodyBlock,
        make.block([make.functionInvocation(breakName)])));
    });

    breakTargets = savedBreakTargets;
    continueTargets = savedContinueTargets;
    currentBlock = savedBlock;
    addStatement(make.functionDeclarationStatement(breakName, [], breakBlock));
    addStatement(
        make.variableDeclarationStatement(scanner.Keyword.VAR,
            [make.variableDeclaration(trampolineName)]));
    addStatement(
        make.functionDeclarationStatement(continueName, [], continueBlock));
    _addTrampoline(trampolineName, make.identifier(continueName));
  };

  visitYieldStatement(ast.YieldStatement node) => unimplemented(node);

  // ---- Expressions ----
  visitAsExpression(ast.AsExpression node) => (ek, sk) {
    return visit(node.expression)(ek, (expr) {
      return sk(make.asExpression(expr, node.type));
    });
  };

  final Map _assignmentToBinaryOperator = {
      scanner.TokenType.AMPERSAND_EQ: scanner.TokenType.AMPERSAND,
      scanner.TokenType.BAR_EQ: scanner.TokenType.BAR,
      scanner.TokenType.CARET_EQ: scanner.TokenType.CARET,
      scanner.TokenType.GT_GT_EQ: scanner.TokenType.GT_GT,
      scanner.TokenType.LT_LT_EQ: scanner.TokenType.LT_LT,
      scanner.TokenType.MINUS_EQ: scanner.TokenType.MINUS,
      scanner.TokenType.PERCENT_EQ: scanner.TokenType.PERCENT,
      scanner.TokenType.PLUS_EQ: scanner.TokenType.PLUS,
      scanner.TokenType.SLASH_EQ: scanner.TokenType.SLASH,
      scanner.TokenType.STAR_EQ: scanner.TokenType.STAR,
      scanner.TokenType.TILDE_SLASH_EQ: scanner.TokenType.TILDE_SLASH,
    };

  visitAssignmentExpression(ast.AssignmentExpression node) => (ek, sk) {
    finishAssignment(lhs) {
      var nameLeft = node.operator.type != scanner.TokenType.EQ &&
          awaits.contains(node.rightHandSide);
      if (nameLeft) {
        var lhsValue = addTempDeclaration(lhs);
        return visit(node.rightHandSide)(ek, (rhs) {
          return sk(make.assignmentExpression(lhs,
              make.binaryExpression(lhsValue,
                  _assignmentToBinaryOperator[node.operator.type],
                  rhs)));
        });
      } else {
        return visit(node.rightHandSide)(ek, (rhs) {
          return sk(make.assignmentExpression(lhs, rhs, node.operator.type));
        });
      }
    }

    var lhs = node.leftHandSide;
    if (lhs is ast.SimpleIdentifier) {
      return finishAssignment(lhs);
    } else if (lhs is ast.PrefixedIdentifier) {
      // TODO(kmillikin): We need resolution to determine what the prefix is.
      // It could be a class or library name, in which case we do not want
      // to rename it.  Or it could be a mutable variable in scope, in
      // which case we do.
      //
      // Translate this as if it were a property access, though that could
      // be wrong.
      var target = lhs.prefix;
      if (awaits.contains(node.rightHandSide)) {
        target = addTempDeclaration(target);
      }
      return finishAssignment(make.propertyAccess(target, lhs.identifier));
    } else if (lhs is ast.PropertyAccess) {
      if (lhs.target != null) {
        return visit(lhs.target)(ek, (target) {
          if (awaits.contains(node.rightHandSide)) {
            target = addTempDeclaration(target);
          }
          return finishAssignment(
              make.propertyAccess(target, lhs.propertyName));
        });
      } else {
        return finishAssignment(make.propertyAccess(null, lhs.propertyName));
      }
    } else if (lhs is ast.IndexExpression) {
      if (lhs.target != null) {
        return visit(lhs.target)(ek, (target) {
          if (awaits.contains(lhs.index) ||
              awaits.contains(node.rightHandSide)) {
            target = addTempDeclaration(target);
          }
          return visit(lhs.index)(ek, (index) {
            if (awaits.contains(node.rightHandSide)) {
              index = addTempDeclaration(index);
            }
            return finishAssignment(make.indexExpression(target, index));
         });
        });
      } else {
        return visit(lhs.index)(ek, (index) {
          if (awaits.contains(node.rightHandSide)) {
            index = addTempDeclaration(index);
          }
          return finishAssignment(make.indexExpression(null, index));
        });
      }
    } else {
      throw  'Unexpected ${lhs.runtimeType} in assignment: $lhs';
    }
  };

  _reifyAwaitContinuation(sk, ek) {
    var parameter = newName('x');
    var savedBlock = currentBlock;
    var tryBlock = currentBlock = make.emptyBlock();
    if (currentStream != null) {
      addStatement(make.methodInvocation(
          make.identifier(currentStream), 'resume', []));
    }
    sk(make.identifier(parameter));

    currentBlock = savedBlock;
    var exceptionName = newName('e');
    var stackTraceName = newName('s');
    var body = make.tryStatement(tryBlock,
        [make.catchClause(null, exceptionName, stackTraceName,
             make.block([ek.apply(exceptionName, stackTraceName)]))]);

    var trampolineName = continueTargets.isEmpty
        ? null
        : continueTargets.last.trampolineName;
    if (trampolineName != null) {
      // We are in a loop if a continue without a label has a trampoline name.
      // If the body of the then callback was `body`, the translation instead
      // produces:
      //   trampoline = () {
      //       trampoline = null;
      //       body
      //   };
      //   do trampoline(); while (trampoline != null);
      savedBlock = currentBlock;
      var trampolineBlock = currentBlock = make.emptyBlock();
      var initialValue = make.functionExpression([], make.block(
          [make.assignmentExpression(make.identifier(trampolineName),
               make.nullLiteral()),
           body]));
      _addTrampoline(trampolineName, initialValue);

      currentBlock = savedBlock;
      body = trampolineBlock;
    }
    return make.functionExpression([parameter], body);
  }

  visitAwaitExpression(ast.AwaitExpression node) => (ek, sk) {
    return visit(node.expression)(ek, (expr) {
      if (currentStream != null) {
        expr = addTempDeclaration(expr);
        addStatement(make.methodInvocation(
            make.identifier(currentStream), 'pause', []));
      }
      var wrapped =
          make.newInstance(make.identifier('Future', 'value'), [expr]);
      addStatement(make.methodInvocation(wrapped, 'then',
          [_reifyAwaitContinuation(sk, ek),
           make.namedExpression('onError', ek.reify())]));
    });
  };

  visitBinaryExpression(ast.BinaryExpression node) => (ek, sk) {
    if (node.operator.lexeme == '&&' || node.operator.lexeme == '||') {
      if (awaits.contains(node.rightOperand)) {
        var joinName = newName('join');
        var joinParameterName = newName('x');
        return visit(node.leftOperand)(ek, (left) {
          var savedBlock = currentBlock;
          var joinBlock = currentBlock = make.emptyBlock();
          sk(make.identifier(joinParameterName));

          var rightBlock = currentBlock = make.emptyBlock();
          visit(node.rightOperand)(ek, (right) {
            addStatement(make.functionInvocation(joinName,
                [make.conditionalExpression(right,
                                            make.booleanLiteral(true),
                                            make.booleanLiteral(false))]));
          });
          currentBlock = savedBlock;
          addStatement(make.functionDeclarationStatement(
              joinName, [joinParameterName], joinBlock));
          if (node.operator.lexeme == '&&') {
            addStatement(make.ifStatement(
                left,
                rightBlock,
                make.block([make.functionInvocation(joinName,
                                [make.booleanLiteral(false)])])));
          } else {
            addStatement(make.ifStatement(
                left,
                make.block([make.functionInvocation(joinName,
                                [make.booleanLiteral(true)])]),
                rightBlock));
          }
        });
      } else {
        return visit(node.leftOperand)(ek, (left) {
          return visit(node.rightOperand)(ek, (right) {
            return sk(make.binaryExpression(left, node.operator.type, right));
          });
        });
      }
    } else {
      return visit(node.leftOperand)(ek, (left) {
        if (awaits.contains(node.rightOperand)) {
          left = addTempDeclaration(left);
        }
       return visit(node.rightOperand)(ek, (right) {
          return sk(make.binaryExpression(left, node.operator.type, right));
        });
      });
    }
  };

  visitCascadeExpression(ast.CascadeExpression node) => (ek, sk) {
    visit(node.target)(ek, (target) {
      if (node.cascadeSections.any(awaits.contains)) {
        target = addTempDeclaration(target);
      }
      var sections = [];
      var cont = (e) {
        sections.add(make.cascadeSection(e));
        return sk(make.cascadeExpression(target, sections));
      };
      for (var i = node.cascadeSections.length - 1; i >= 1; --i) {
        var nextCont = cont;
        // The continuation for the i-1 cascade section.
        cont = (e) {
          sections.add(make.cascadeSection(e));
          var nextSection = node.cascadeSections[i];
          if (awaits.contains(nextSection) && sections.isNotEmpty) {
            addStatement(make.cascadeExpression(target, sections));
            sections.clear();
          }
          return visit(nextSection)(ek, nextCont);
        };
      }
      return visit(node.cascadeSections.first)(ek, cont);
    });
  };

  visitConditionalExpression(ast.ConditionalExpression node) => (ek, sk) {
    return visit(node.condition)(ek, (expr) {
      var savedBlock = currentBlock;
      var joinName = newName('join');
      var joinParameterName = newName('x');
      var joinBlock = currentBlock = make.emptyBlock();
      sk(make.identifier(joinParameterName));

      var cont = (e) {
        addStatement(make.functionInvocation(joinName, [e]));
      };
      var thenBlock = currentBlock = make.emptyBlock();
      visit(node.thenExpression)(ek, cont);
      var elseBlock = currentBlock = make.emptyBlock();
      visit(node.elseExpression)(ek, cont);
      currentBlock = savedBlock;
      addStatement(make.functionDeclarationStatement(
          joinName, [joinParameterName], joinBlock));
      addStatement(make.ifStatement(expr, thenBlock, elseBlock));
    });
  };

  visitFunctionExpression(ast.FunctionExpression node) => (ek, sk) {
    node.body = new AsyncTransformer().visit(node.body);
    return sk(make.parenthesizedExpression(node));
  };

  visitFunctionExpressionInvocation(
      ast.FunctionExpressionInvocation node) => (ek, sk) {
    return visit(node.function)(ek, (rator) {
      if (awaits.contains(node.argumentList)) {
        rator = addTempDeclaration(rator);
      }
      return _translateExpressionList(node.argumentList.arguments, ek, (rands) {
        return sk(make.functionInvocation(rator, rands));
      });
    });
  };

  // ---- Identifiers ----
  visitSimpleIdentifier(ast.SimpleIdentifier node) => (ek, sk) {
    return sk(node);
  };

  visitPrefixedIdentifier(ast.PrefixedIdentifier node) => (ek, sk) {
    return sk(node);
  };

  visitIndexExpression(ast.IndexExpression node) => (ek, sk) {
    return visit(node.target)(ek, (e0) {
      if (awaits.contains(node.index)) {
        e0 = addTempDeclaration(e0);
      }
      return visit(node.index)(ek, (e1) {
        return sk(make.indexExpression(e0, e1));
      });
    });
  };

  _translateExpressionList(ast.NodeList<ast.Expression> exprs, ek, sk) {
    if (exprs.isEmpty) {
      return sk([]);
    }
    var args = [];
    var seenAwait = false;
    var cont = (v) {
      args.add(v);
      return sk(args);
    };
    for (var i = exprs.length - 1; i >= 1; --i) {
      var expr = exprs[i];
      seenAwait = seenAwait || awaits.contains(expr);
      var current = cont;
      if (seenAwait) {
        cont = (v) {
          var value = addTempDeclaration(v);
          args.add(value);
          return visit(expr)(ek, current);
        };
      } else {
        cont = (v) {
          args.add(v);
          return visit(expr)(ek, current);
        };
      }
    }
    return visit(exprs.first)(ek, cont);
  }

  visitInstanceCreationExpression(
      ast.InstanceCreationExpression node) => (ek, sk) {
    return _translateExpressionList(node.argumentList.arguments, ek, (rands) {
      return sk(make.newInstance(node.constructorName,
          rands, scanner.Keyword.keywords[node.keyword.lexeme]));
    });
  };

  visitIsExpression(ast.IsExpression node) => (ek, sk) {
    return visit(node.expression)(ek, (expr) {
      return sk(make.isExpression(expr, node.notOperator != null, node.type));
    });
  };

  // ---- Literals ----
  visitBooleanLiteral(ast.BooleanLiteral node) => (ek, sk) {
    return sk(node);
  };

  visitDoubleLiteral(ast.DoubleLiteral node) => (ek, sk) {
    return sk(node);
  };

  visitIntegerLiteral(ast.IntegerLiteral node) => (ek, sk) {
    return sk(node);
  };

  visitNullLiteral(ast.NullLiteral node) => (ek, sk) {
    return sk(node);
  };

  // ---- StringLiterals ----
  visitAdjacentStrings(ast.AdjacentStrings node) => (ek, sk) {
    assert(node.strings.isNotEmpty);
    // This code relies on translating a StringLiteral never passing a
    // non-StringLiteral to its success continuation.
    var strings = [];
    var cont = (e) {
      strings.add(e);
      return sk(make.adjacentStrings(strings));
    };
    for (var i = node.strings.length - 1; i >= 1; --i) {
      // Build the continuation for the i-1 string.
      var nextCont = cont;
      cont = (e) {
        strings.add(e);
        return visit(node.strings[i])(ek, nextCont);
      };
    }
    return visit(node.strings.first)(ek, cont);
  };

  visitSimpleStringLiteral(ast.SimpleStringLiteral node) => (ek, sk) {
    // The translation of adjacent strings relies on never passing a
    // non-StringLiteral to the success continuation here.
    return sk(node);
  };

  visitStringInterpolation(ast.StringInterpolation node) => (ek, sk) {
    var list = new ast.NodeList<ast.Expression>(node);
    for (var element in node.elements) {
      if (element is ast.InterpolationExpression) {
        list.add(element.expression);
      } else {
        assert(element is ast.InterpolationString);
      }
    }
    return _translateExpressionList(list, ek, (exprs) {
      var elements = <ast.InterpolationElement>[];
      int index = 0;
      for (var element in node.elements) {
        if (element is ast.InterpolationExpression) {
          elements.add(make.interpolationExpression(exprs[index++]));
        } else {
          elements.add(element);
        }
      }
      // The translation of adjacent strings relies on never passing a
      // non-StringLiteral to the success continuation here.
      return sk(make.stringInterpolation(elements));
    });
  };

  visitSymbolLiteral(ast.SymbolLiteral node) => (ek, sk) {
    return sk(node);
  };

  // ---- TypedLiterals ----
  visitListLiteral(ast.ListLiteral node) => (ek, sk) {
    return _translateExpressionList(node.elements, ek, (elts) {
      return sk(make.listLiteral(elts));
    });
  };

  visitMapLiteral(ast.MapLiteral node) => (ek, sk) {
    var list = new ast.NodeList<ast.Expression>(node);
    for (var entry in node.entries) {
      list.add(entry.key);
      list.add(entry.value);
    }
    return _translateExpressionList(list, ek, (exprs) {
      var entries = <ast.MapLiteralEntry>[];
      for (var i = 0; i < exprs.length; i += 2) {
        entries.add(new ast.MapLiteralEntry(
            exprs[i],
            TokenFactory.tokenFromType(scanner.TokenType.COLON),
            exprs[i + 1]));
      }
      return sk(make.mapLiteral(entries));
    });
  };

  visitMethodInvocation(ast.MethodInvocation node) => (ek, sk) {
    if (node.target != null) {
      return visit(node.target)(ek, (rator) {
        if (awaits.contains(node.argumentList)) {
          rator = addTempDeclaration(rator);
        }
        return _translateExpressionList(node.argumentList.arguments, ek,
            (rands) {
              return sk(make.methodInvocation(
                  rator, node.methodName.name, rands));
            });
      });
    } else {
      return _translateExpressionList(node.argumentList.arguments, ek, (rands) {
        return sk(make.methodInvocation(null, node.methodName.name, rands));
      });
    }
  };

  visitNamedExpression(ast.NamedExpression node) => (ek, sk) {
    return visit(node.expression)(ek, (expr) {
      return sk(make.namedExpression(node.name, expr));
    });
  };

  visitParenthesizedExpression(ast.ParenthesizedExpression node) => (ek, sk) {
    return visit(node.expression)(ek, (expr) {
      return sk(make.parenthesizedExpression(expr));
    });
  };

  visitPostfixExpression(ast.PostfixExpression node) => (ek, sk) {
    return visit(node.operand)(ek, (expr) {
      return sk(make.postfixExpression(expr, node.operator.type));
    });
  };

  visitPrefixExpression(ast.PrefixExpression node) => (ek, sk) {
    return visit(node.operand)(ek, (expr) {
      return sk(make.prefixExpression(node.operator.type, expr));
    });
  };

  visitPropertyAccess(ast.PropertyAccess node) => (ek, sk) {
    return visit(node.target)(ek, (expr) {
      return sk(make.propertyAccess(expr, node.propertyName));
    });
  };

  // `rethrow` is not an expression but a statement in Dart.  The analyzer
  // however parses it as an expression inside an expression statement.
  visitRethrowExpression(ast.RethrowExpression node) => (ek, sk) {
    // `rethrow` is not translated as `throw` to avoid changing the stack
    // trace.  It is safe to apply ek (and ignore sk) because rethrow is
    // actually a statement --- sk includes only the translation of code that
    // will be aborted by the rethrow anyway.
    assert(currentExceptionName != null);
    return addStatement(ek.apply(currentExceptionName, currentStackTraceName));
  };

  visitSuperExpression(ast.SuperExpression node) => (ek, sk) {
    return sk(node);
  };

  visitThisExpression(ast.ThisExpression node) => (ek, sk) {
    return sk(node);
  };

  visitThrowExpression(ast.ThrowExpression node) => (ek, sk) {
    return visit(node.expression)(ek, (expr) {
      // `throw` is always translated as `throw` to ensure that a stack
      // trace is produced.  The translation ensures that all code is inside
      // an try/catch with an appropriate error handler.
      return sk(make.throwExpression(expr));
    });
  };

  unreachable(node) => throw 'Unreachable(${node.runtimeType})';
  visitAnnotation(node) => unreachable(node);
  visitArgumentList(node) => unreachable(node);
  visitCatchClause(node) => unreachable(node);
  visitComment(node) => unreachable(node);
  visitCommentReference(node) => unreachable(node);
  visitConstructorFieldInitializer(node) => unreachable(node);
  visitConstructorName(node) => unreachable(node);
  visitDeclaredIdentifier(node) => unreachable(node);
  visitDefaultFormalParameter(node) => unreachable(node);
  visitEnumConstantDeclaration(node) => unreachable(node);
  visitExportDirective(node) => unreachable(node);
  visitExtendsClause(node) => unreachable(node);
  visitFieldFormalParameter(node) => unreachable(node);
  visitFormalParameterList(node) => unreachable(node);
  visitFunctionTypedFormalParameter(node) => unreachable(node);
  visitHideCombinator(node) => unreachable(node);
  visitImplementsClause(node) => unreachable(node);
  visitImportDirective(node) => unreachable(node);
  visitInterpolationExpression(node) => unreachable(node);
  visitInterpolationString(node) => unreachable(node);
  visitLabel(node) => unreachable(node);
  visitLibraryDirective(node) => unreachable(node);
  visitLibraryIdentifier(node) => unreachable(node);
  visitMapLiteralEntry(node) => unreachable(node);
  visitNativeClause(node) => unreachable(node);
  visitPartDirective(node) => unreachable(node);
  visitPartOfDirective(node) => unreachable(node);
  visitRedirectingConstructorInvocation(node) => unreachable(node);
  visitScriptTag(node) => unreachable(node);
  visitShowCombinator(node) => unreachable(node);
  visitSimpleFormalParameter(node) => unreachable(node);
  visitSuperConstructorInvocation(node) => unreachable(node);
  visitSwitchCase(node) => unreachable(node);
  visitSwitchDefault(node) => unreachable(node);
  visitTypeArgumentList(node) => unreachable(node);
  visitTypeName(node) => unreachable(node);
  visitTypeParameter(node) => unreachable(node);
  visitTypeParameterList(node) => unreachable(node);
  visitVariableDeclaration(node) => unreachable(node);
  visitVariableDeclarationList(node) => unreachable(node);
  visitWithClause(node) => unreachable(node);
}

class SyncTransformer extends ast.RecursiveAstVisitor {
  visit(ast.AstNode node) => node.accept(this);

  visitFunctionExpression(ast.FunctionExpression node) {
    if (node.body.isGenerator) {
      throw 'Transfomer: unsupported generator function.';
    }
    visit(node.parameters);
    if (node.body.isAsynchronous) {
      node.body = new AsyncTransformer().visit(node.body);
    } else {
      visit(node.body);
    }
  }
}
