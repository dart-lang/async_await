library async_await.src.xform;

import 'package:analyzer/src/generated/ast.dart' as ast;
import 'package:analyzer/src/generated/scanner.dart' as scanner;
import 'package:analyzer/src/generated/testing/ast_factory.dart';
import 'package:analyzer/src/generated/testing/token_factory.dart';

class Analysis extends ast.GeneralizingAstVisitor<bool> {
  Set<ast.AstNode> awaits = new Set<ast.AstNode>();
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
    if (node.catchClauses.isNotEmpty) {
      if (node.catchClauses.length != 1) {
        throw 'Analysis: unimplemented(TryStatement)';
      }
      if (visit(node.catchClauses.first)) result = true;
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

  bool visitFunctionExpressionInvocation(ast.FunctionExpressionInvocation node) {
   return maybeAdd(node, visit(node.argumentList));
  }

  bool visitIndexExpression(ast.IndexExpression node) {
    var result = visit(node.target);
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

  bool visitPrefixedIdentifier(ast.PrefixedIdentifier node) {
    names.add(node.prefix.name);
    names.add(node.identifier.name);
    return false;
  }

  bool visitPrefixExpression(ast.PrefixExpression node) {
    return maybeAdd(node, visit(node.operand));
  }

  bool visitPropertyAccess(ast.PropertyAccess node) {
    return maybeAdd(node, visit(node.target));
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

// AST construction functions.
ast.SimpleIdentifier identifier(String name) {
  return AstFactory.identifier3(name);
}

ast.FunctionExpression functionExpression(List<String> parameters,
    ast.AstNode body) {
  var formalParameters =
      AstFactory.formalParameterList(
          parameters.map(AstFactory.simpleFormalParameter3).toList());
  var functionBody;
  if (body is ast.Block) {
    functionBody = AstFactory.blockFunctionBody(body);
  } else if (body is ast.Statement) {
    functionBody = AstFactory.blockFunctionBody(AstFactory.block([body]));
  } else {
    assert(body is ast.Expression);
    functionBody = AstFactory.expressionFunctionBody(body);
    functionBody.semicolon = null;
  }
  return AstFactory.functionExpression2(formalParameters, functionBody);
}

ast.VariableDeclarationStatement variableDeclaration(
    String name, ast.Expression initializer) {
  return AstFactory.variableDeclarationStatement2(
          scanner.Keyword.FINAL,
          [AstFactory.variableDeclaration2(name, initializer)]);
}

ast.Block emptyBlock() {
  return AstFactory.block([]);
}

ast.Block block(List<ast.AstNode> body) {
  var stmts = body.map((node) {
    if (node is ast.Expression) {
      return AstFactory.expressionStatement(node);
    } else {
      assert(node is ast.Statement);
      return node;
    }
  }).toList();
  return AstFactory.block(stmts);
}

ast.NullLiteral nullLiteral() {
  return AstFactory.nullLiteral();
}

ast.MethodInvocation methodInvocation(receiver,
                                      String name,
                                      List<ast.AstNode> args) {
  if (receiver == null) {
    return AstFactory.methodInvocation2(name, args);
  } else if (receiver is String) {
    return AstFactory.methodInvocation(identifier(receiver), name, args);
  } else {
    assert(receiver is ast.Expression);
    return AstFactory.methodInvocation(receiver, name, args);
  }
}

class AsyncTransformer extends ast.AstVisitor {
  Set<ast.AstNode> awaits;
  Set<String> names;

  ast.Block currentBlock;
  List<ast.Expression> breakTargets;
  List<ast.Expression> breakLabels;

  List<ast.Expression> continueTargets;
  List<ast.Expression> continueLabels;

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
    currentBlock = emptyBlock();
    breakTargets = <ast.Expression>[];
    breakLabels = <String>[];
    continueTargets = <ast.Expression>[];
    continueLabels = <ast.Expression>[];
    awaits = analysis.awaits;
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
    return identifier(name);
  }

  void addStatement(ast.AstNode node) {
    if (node is ast.Statement) {
      currentBlock.statements.add(node);
    } else {
      assert(node is ast.Expression);
      currentBlock.statements.add(AstFactory.expressionStatement(node));
    }
  }

  ast.FunctionExpression reifyExpressionCont(s, f) {
    var savedBlock = currentBlock;
    var exnBlock = currentBlock = emptyBlock();
    var exnName = newName('e');
    f(identifier(exnName));

    currentBlock = emptyBlock();
    var name = newName('x');
    s(identifier(name));

    var fun =
        functionExpression(
            [name],
            AstFactory.tryStatement2(
                currentBlock,
                [AstFactory.catchClause(exnName, exnBlock.statements)]));
    currentBlock = savedBlock;
    return fun;
  }

  ast.FunctionExpression reifyErrorCont(f) {
    var savedBlock = currentBlock;
    currentBlock = emptyBlock();
    String name = newName('e');
    f(identifier(name));
    var fun = functionExpression([name], currentBlock);
    currentBlock = savedBlock;
    return fun;
  }

  ast.FunctionExpression reifyStatementCont(s) {
    var savedBlock = currentBlock;
    currentBlock = emptyBlock();
    s();
    var fun = functionExpression([], currentBlock);
    currentBlock = savedBlock;
    return fun;
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
    if (node.isSynchronous || node.isGenerator) return node;

    Analysis analysis = new Analysis();
    analysis.visit(node.block);
    reset(analysis);

    var completer = newName('completer');
    visit(node.block)((e) {
      addStatement(methodInvocation(completer, 'completeError', [e]));
    }, (v) {
      addStatement(methodInvocation(completer, 'complete', [v]));
    }, () {
      addStatement(methodInvocation(completer, 'complete', [nullLiteral()]));
    });

    String exnName = newName('e');
    return AstFactory.blockFunctionBody2(
        [variableDeclaration(
              completer,
              AstFactory.instanceCreationExpression2(
                  scanner.Keyword.NEW,
                  AstFactory.typeName4('Completer', []),
                  [])),
          AstFactory.expressionStatement(
              AstFactory.methodInvocation2(
                  'scheduleMicrotask',
                  [functionExpression(
                        [],
                        AstFactory.tryStatement2(
                            currentBlock,
                            [AstFactory.catchClause(
                                  exnName,
                                  [AstFactory.expressionStatement(
                                        AstFactory.methodInvocation(
                                            identifier(completer),
                                            'completeError',
                                            [identifier(exnName)]))])]))])),
          AstFactory.returnStatement2(
              AstFactory.propertyAccess2(identifier(completer), 'future'))]);
  }

  visitEmptyFunctionBody(ast.EmptyFunctionBody node) {
    return node;
  }

  visitExpressionFunctionBody(ast.ExpressionFunctionBody node) {
    if (node.isSynchronous || node.isGenerator) return node;
    return visit(AstFactory.blockFunctionBody2(
        [AstFactory.returnStatement2(node.expression)])
        ..keyword = node.keyword);
  }

  visitNativeFunctionBody(ast.NativeFunctionBody node) {
    return node;
  }

  // ---- Statements ----
  unimplemented(ast.AstNode node) => throw 'Unimplemented(${node.runtimeType})';

  visitAssertStatement(ast.AssertStatement node) => (f, r, s) {
    return visit(node.condition)(f, (cond) {
      addStatement(AstFactory.assertStatement(cond));
      return s();
    });
  };

  _translateStatementList(ast.NodeList<ast.Statement> list, f, r, s) {
    for (var stmt in list.reversed) {
      var nextCont = s;
      s = () => visit(stmt)(f, r, nextCont);
    }
    return s();
  }

  visitBlock(ast.Block node) => (f, r, s) {
    return _translateStatementList(node.statements, f, r, s);
  };

  visitBreakStatement(ast.BreakStatement node) => (f, r, s) {
    var target;

    if (node.label != null) {
      var i;
      for(i = breakLabels.length-1; i >= 0; i--) {
        if(breakLabels[i] == node.label.name) break;
      }
      target = breakTargets[i];
    } else {
      target = breakTargets.last;
    }
    addStatement(AstFactory.functionExpressionInvocation(
        target, [nullLiteral()]));
  };

  visitContinueStatement(ast.ContinueStatement node) => (f, r, s) {
    if (node.label != null) unimplemented(node);
    addStatement(AstFactory.functionExpressionInvocation(
            continueTargets.last, [nullLiteral()]));
  };

  visitDoStatement(ast.DoStatement node) => (f, r, s) {
    var breakName = newName('break');
    var continueName = newName('continue');
    var loopName = newName('loop');

    var savedBlock = currentBlock;
    var breakBlock = currentBlock = emptyBlock();
    s();

    var continueBlock = currentBlock = emptyBlock();
    visit(node.condition)(f, (expr) {
      addStatement(AstFactory.ifStatement2(
          expr,
          block([AstFactory.methodInvocation(
              AstFactory.functionExpressionInvocation(
                  AstFactory.identifier(identifier('Future'),
                                        identifier('wait')),
                  [AstFactory.listLiteral([])]),
              'then',
              [identifier(loopName)])]),
          block([AstFactory.functionExpressionInvocation(
              identifier(breakName), [nullLiteral()])])));
    });

    var loopBlock = currentBlock = emptyBlock();
    addStatement(
        AstFactory.functionDeclarationStatement(null, null, continueName,
            functionExpression([newName('x')], continueBlock)));
    breakTargets.add(identifier(breakName));
    breakLabels.add(breakName);
    continueTargets.add(identifier(continueName));
    visit(node.body)(f, r, () {
      addStatement(
          AstFactory.functionExpressionInvocation(
              identifier(continueName), [nullLiteral()]));
    });
    breakTargets.removeLast();
    breakLabels.removeLast();
    continueTargets.removeLast();

    currentBlock = savedBlock;
    addStatement(
        AstFactory.functionDeclarationStatement(null, null, breakName,
            functionExpression([newName('x')], breakBlock)));
    addStatement(
        AstFactory.functionDeclarationStatement(null, null, loopName,
            functionExpression([newName('x')], loopBlock)));
    addStatement(
        AstFactory.functionExpressionInvocation(
            identifier(loopName), [nullLiteral()]));
  };

  visitEmptyStatement(ast.EmptyStatement node) => (f, r, s) {
    return s();
  };

  visitExpressionStatement(ast.ExpressionStatement node) => (f, r, s) {
    return visit(node.expression)(f, (expr) {
      addStatement(expr);
      return s();
    });
  };

  visitForEachStatement(ast.ForEachStatement node) {
    var stmt = emptyBlock();
    var it = newName('it');
    stmt.statements.add(
        AstFactory.variableDeclarationStatement2(
            scanner.Keyword.VAR,
            [AstFactory.variableDeclaration2(it,
                AstFactory.propertyAccess2(node.iterator, 'iterator'))]));
    var body;
    if (node.identifier != null) {
      body = block(
          [AstFactory.assignmentExpression(
               node.identifier,
               scanner.TokenType.EQ,
               AstFactory.propertyAccess2(identifier(it), 'current')),
           node.body]);
    } else {
      assert(node.loopVariable != null);
      body = block(
          [AstFactory.variableDeclarationStatement2(
              scanner.Keyword.keywords[node.loopVariable.keyword.lexeme],
              [AstFactory.variableDeclaration2(
                   node.loopVariable.identifier.name,
                   AstFactory.propertyAccess2(identifier(it), 'current'))]),
           node.body]);
    }
    stmt.statements.add(AstFactory.whileStatement(
        AstFactory.methodInvocation(identifier(it), 'moveNext', []),
        body));
    return visitBlock(stmt);
  }

  _translateForUpdaters(List<ast.Expression> exprs, f, s) {
    var cont = s;
    for (var expr in exprs.reversed) {
      var nextCont = cont;
      cont = () {
        visit(expr)(f, (expr) {
          addStatement(expr);
          return nextCont();
        });
      };
     }
     return cont();
   }

  _translateForDeclarations(List<ast.VariableDeclaration> decls, f, s) {
    var exprs = [];
    var seenAwait = false;
    var cont = (e) {
      exprs.add(e);
      return s(exprs);
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
            ? nextCont(nullLiteral())
            : visit(nextExpr)(f, nextCont);
      };
    }
    var expr = decls.first.initializer;
    return (expr == null)
        ? cont(nullLiteral())
        :  visit(expr)(f, cont);
  }

 visitForStatement(ast.ForStatement node) => (f, r, s) {
    var breakName = newName('break');
    var continueName = newName('continue');
    var loopName = newName('loop');

    var savedBlock = currentBlock;
    var breakBlock = currentBlock = emptyBlock();
    s();

    var parameters;
    if (node.variables != null) {
      parameters = node.variables.variables.map((d) => d.name).toList();
    } else {
      parameters = <ast.SimpleIdentifier>[];
    }

    var continueBlock = currentBlock = emptyBlock();
    trampoline() {
      addStatement(
          AstFactory.methodInvocation(
              AstFactory.functionExpressionInvocation(
                  AstFactory.identifier(identifier('Future'),
                                        identifier('wait')),
                  [AstFactory.listLiteral([])]),
              'then',
              [functionExpression ([newName('x')],
                  AstFactory.functionExpressionInvocation(
                      identifier(loopName),
                      parameters))]));
    }
    if (node.updaters != null) {
      _translateForUpdaters(node.updaters, f, trampoline);
    } else {
      trampoline();
    }

    var bodyBlock = currentBlock = emptyBlock();
    breakTargets.add(identifier(breakName));
    breakLabels.add(breakName);
    continueTargets.add(identifier(continueName));
    visit(node.body)(f, r, () {
      addStatement(
          AstFactory.functionExpressionInvocation(
              identifier(continueName), [nullLiteral()]));
    });
    breakTargets.removeLast();
    breakLabels.removeLast();
    continueTargets.removeLast();

    var loopBlock = currentBlock = emptyBlock();
    addStatement(
        AstFactory.functionDeclarationStatement(null, null, continueName,
            functionExpression([newName('x')], continueBlock)));
    if (node.condition != null) {
      visit(node.condition)(f, (expr) {
        addStatement(AstFactory.ifStatement2(
          expr,
          bodyBlock,
          block([AstFactory.functionExpressionInvocation(
              identifier(breakName), [nullLiteral()])])));
      });
    } else {
      addStatement(bodyBlock);
    }

    currentBlock = savedBlock;
    addStatement(
        AstFactory.functionDeclarationStatement(null, null, breakName,
            functionExpression([newName('x')], breakBlock)));
    addStatement(
        AstFactory.functionDeclarationStatement(null, null, loopName,
            functionExpression(parameters.map((e) => e.name).toList(),
                loopBlock)));
    if (node.variables != null) {
      assert(node.variables.variables.isNotEmpty);
      return _translateForDeclarations(node.variables.variables, f, (args) {
        assert(args.length == parameters.length);
        addStatement(AstFactory.functionExpressionInvocation(
            identifier(loopName), args));
      });
    } else if (node.initialization != null) {
      assert(parameters.isEmpty);
      return visit(node.initialization)(f, (expr) {
        addStatement(expr);
        addStatement(AstFactory.functionExpressionInvocation(
            identifier(loopName), []));
      });
    } else {
      assert(parameters.isEmpty);
      return addStatement(AstFactory.functionExpressionInvocation(
          identifier(loopName), []));
    }
  };

  visitFunctionDeclarationStatement(ast.FunctionDeclarationStatement node) {
    return unimplemented(node);
  }

  visitIfStatement(ast.IfStatement node) => (f, r, s) {
    var hasElse = node.elseStatement != null;
    return visit(node.condition)(f, (expr) {
      var joinName = newName('join');
      var joinFun = reifyStatementCont(s);
      addStatement(
          AstFactory.functionDeclarationStatement(
              null, null, joinName, joinFun));
      s = () {
        addStatement(AstFactory.methodInvocation2(joinName, []));
      };
      var savedBlock = currentBlock;
      var thenBlock = currentBlock = emptyBlock();
      visit(node.thenStatement)(f, r, s);
      var elseBlock = currentBlock = emptyBlock();
      if (hasElse) {
        visit(node.elseStatement)(f, r, s);
      } else {
        s();
      }
      currentBlock = savedBlock;
      addStatement(AstFactory.ifStatement2(expr, thenBlock, elseBlock));
    });
  };

  visitLabeledStatement(ast.LabeledStatement node) => (f,r,s) {
    // if loop recurse immediately

    var breakName = newName('break');
    var savedBlock = currentBlock;
    var breakBlock = currentBlock = emptyBlock();
    s();
    currentBlock = savedBlock;

    addStatement(
        AstFactory.functionDeclarationStatement(
          null,
          null,
          breakName,
          functionExpression([newName('x')], breakBlock)));

    for(var label in node.labels) {
      breakLabels.add(label.label.name);
      breakTargets.add(identifier(breakName));
    }

    visit(node.statement) (f,r, () {
      addStatement(
        AstFactory.functionExpressionInvocation(
            identifier(breakName), [nullLiteral()]));
    });

    var delta = node.labels.length;
    breakLabels.length -= delta; breakTargets.length -= delta;

  };

  visitRethrowExpression(ast.RethrowExpression node) => unimplemented(node);

  visitReturnStatement(ast.ReturnStatement node) => (f, r, s) {
    return (node.expression == null)
        ? r(AstFactory.nullLiteral())
        : visit(node.expression)(f, (v) => r(v));
  };

  visitSwitchStatement(ast.SwitchStatement node) => (f, r, s) {
    return visit(node.expression)(f, (expr) {
      var breakName = newName('break');
      ast.FunctionExpression breakFun = reifyStatementCont(s);
      breakFun.parameters = AstFactory.formalParameterList(
          [AstFactory.simpleFormalParameter3(newName('x'))]);
      addStatement(
          AstFactory.functionDeclarationStatement(
              null, null, breakName, breakFun));

      // Generate a name per labeled case.
      var continueNames = [];
      for (var member in node.members) {
        if (member.labels.isNotEmpty) continueNames.add(newName('continue'));
      }

      // Translate the cases with bindings for the break and possible
      // continues.
      breakTargets.add(identifier(breakName));
      continueTargets.addAll(continueNames.map(identifier));
      if (continueNames.isNotEmpty) {
        // Add declarations for mutable continue functions.
        addStatement(
            AstFactory.variableDeclarationStatement2(scanner.Keyword.VAR,
                continueNames.map(AstFactory.variableDeclaration).toList()));

        // Translate the labeled cases as recursive functions.
        var index = 0;
        for (var member in node.members) {
          if (member.labels.isEmpty) continue;
          var savedBlock = currentBlock;
          var caseBlock = currentBlock = emptyBlock();
          _translateStatementList(member.statements, f, r, () {
            addStatement(AstFactory.functionExpressionInvocation(
                identifier(breakName), [nullLiteral()]));
          });
          currentBlock = savedBlock;
          addStatement(AstFactory.assignmentExpression(
              identifier(continueNames[index]), scanner.TokenType.EQ,
              functionExpression([newName('x')], caseBlock)));
          ++index;
        }
      }

      // Translate the unlabeled cases as blocks and the labeled cases as
      // calls to the corresponding continue function.
      var savedBlock = currentBlock;
      var members = [];
      var index = 0;
      for (var member in node.members) {
        var bodyBlock;
        if (member.labels.isEmpty) {
          bodyBlock = currentBlock = emptyBlock();
          _translateStatementList(member.statements, f, r, () {
            addStatement(AstFactory.functionExpressionInvocation(
                identifier(breakName), [nullLiteral()]));
          });
        } else {
          bodyBlock = block([AstFactory.functionExpressionInvocation(
              identifier(continueNames[index]), [nullLiteral()])]);
          ++index;
        }
        // Cases must end with return, break, continue, or throw.
        bodyBlock.statements.add(AstFactory.returnStatement());
        if (member is ast.SwitchDefault) {
          members.add(AstFactory.switchDefault2(bodyBlock.statements));
        } else {
          members.add(AstFactory.switchCase(member.expression,
              bodyBlock.statements));
        }
      }
      breakTargets.removeLast();
      continueTargets.length -= continueNames.length;
      currentBlock = savedBlock;
      addStatement(AstFactory.switchStatement(expr, members));
    });
  };

  visitCatchClause(ast.CatchClause node) => (f, r, s) {
    // TODO(kmillikin): handle 'on T catch' clauses.
    return visit(node.body)(f, r, s);
  };

  visitTryStatement(ast.TryStatement node) => (f, r, s) {
    var joinName = newName('join');
    ast.FunctionExpression joinFun = reifyStatementCont(s);
    joinFun.parameters = AstFactory.formalParameterList(
        [AstFactory.simpleFormalParameter3(newName('x'))]);
    addStatement(
        AstFactory.functionDeclarationStatement(null, null, joinName, joinFun));

    var finallyName = newName('finally');
    var finallyContName = newName('cont');
    var finallyValueName = newName('v');
    var savedBlock = currentBlock;
    var finallyBlock = currentBlock = emptyBlock();
    s = () {
      addStatement(AstFactory.functionExpressionInvocation(
              identifier(finallyContName),
              [identifier(finallyValueName)]));
    };
    if (node.finallyBlock != null) {
      visit(node.finallyBlock)(f, r, s);
    } else {
      s();
    }

    var catchName = newName('catch');
    var exnName = node.catchClauses.isEmpty ?
        newName('e') :
        node.catchClauses.first.exceptionParameter.name;
    var catchBlock = currentBlock = emptyBlock();
    var savedBreakTargets = breakTargets;
    var savedContinueTargets = continueTargets;
    breakTargets = breakTargets.map((expr) {
      return AstFactory.parenthesizedExpression(
              functionExpression([newName('x')],
                  AstFactory.functionExpressionInvocation(
                      identifier(finallyName), [expr, nullLiteral()])));
    }).toList();
    continueTargets = continueTargets.map((expr) {
      return AstFactory.parenthesizedExpression(
          functionExpression([newName('x')],
               AstFactory.functionExpressionInvocation(
                  identifier(finallyName), [expr, nullLiteral()])));
    }).toList();
    if (node.catchClauses.isNotEmpty) {
      assert(node.catchClauses.length == 1);
      visit(node.catchClauses.first)((e) {
        addStatement(
            AstFactory.methodInvocation2(finallyName, [reifyErrorCont(f), e]));
      }, (v) {
        addStatement(
            AstFactory.methodInvocation2(finallyName, [reifyErrorCont(r), v]));
      }, () {
        addStatement(
            AstFactory.methodInvocation2(
                finallyName,
                [identifier(joinName), AstFactory.nullLiteral()]));
      });
    } else {
      addStatement(
          AstFactory.methodInvocation2(
              finallyName,
              [identifier(joinName), AstFactory.nullLiteral()]));
    }

    var tryBlock = currentBlock = emptyBlock();
    visit(node.body)((e) {
      addStatement(AstFactory.methodInvocation2(catchName, [e]));
    }, (v) {
      addStatement(
          AstFactory.methodInvocation2(finallyName, [reifyErrorCont(r), v]));
    }, () {
      addStatement(
          AstFactory.expressionStatement(
              AstFactory.methodInvocation2(
                  finallyName,
                  [identifier(joinName), AstFactory.nullLiteral()])));
    });

    currentBlock = savedBlock;
    breakTargets = savedBreakTargets;
    continueTargets = savedContinueTargets;
    addStatement(
        AstFactory.functionDeclarationStatement(
            null,
            null,
            finallyName,
            functionExpression([finallyContName, finallyValueName], finallyBlock)));

    addStatement(
        AstFactory.functionDeclarationStatement(
            null,
            null,
            catchName,
            functionExpression([exnName], catchBlock)));
    var name = newName('e');
    addStatement(
        AstFactory.tryStatement2(
            tryBlock,
            [AstFactory.catchClause(
                  name,
                  [AstFactory.expressionStatement(
                        AstFactory.methodInvocation2(
                            catchName, [identifier(name)]))])]));
  };

  _translateDeclarationList(scanner.Keyword keyword,
      ast.VariableDeclarationList node) => (f, s) {
    translateDecl(ast.VariableDeclaration decl, cont) {
      if (decl.initializer == null) {
        return cont(decl);
      } else {
        return visit(decl.initializer)(f, (expr) {
          return cont(AstFactory.variableDeclaration2(decl.name.name, expr));
        });
      }
    }

    var decls = [];
    // The continuation for the last declaration.
    var cont = (decl) {
      decls.add(decl);
      return s(decls);
    };
    for (var i = node.variables.length - 1; i >= 1; --i) {
      var nextCont = cont;
      // The continuation for the i-1 declaration.
      cont = (decl) {
        decls.add(decl);
        var nextDecl = node.variables[i];
        if (awaits.contains(nextDecl)) {
          _residualizeDeclarationList(keyword, decls);
          decls.clear();
        }
        translateDecl(nextDecl, nextCont);
      };
    }
    translateDecl(node.variables.first, cont);
  };

  void _residualizeDeclarationList(scanner.Keyword keyword,
      List<ast.VariableDeclaration> decls) {
    if (decls.isEmpty) return;
    addStatement(AstFactory.variableDeclarationStatement2(keyword, decls));
  }

  visitVariableDeclarationStatement(
      ast.VariableDeclarationStatement node) => (f, r, s) {
    var keyword = scanner.Keyword.keywords[node.variables.keyword.lexeme];
    return _translateDeclarationList(keyword, node.variables)(f, (decls) {
      _residualizeDeclarationList(keyword, decls);
      return s();
    });
  };

  visitWhileStatement(ast.WhileStatement node) => (f, r, s) {

    var breakName = newName('break');
    var continueName = newName('continue');

    var savedBlock = currentBlock;
    var breakBlock = currentBlock = emptyBlock();
    s();

    var continueBlock = currentBlock = emptyBlock();
    visit(node.condition)(f, (expr) {
      var savedBlock = currentBlock;
      var bodyBlock = currentBlock = emptyBlock();

      breakTargets.add(identifier(breakName));
      breakLabels.add(breakName);

      continueTargets.add(identifier(continueName));

      visit(node.body)(f, r, () {
        addStatement(
            AstFactory.functionExpressionInvocation(
              identifier(continueName), [nullLiteral()]));
      });

      breakTargets.removeLast();
      breakLabels.removeLast();

      continueTargets.removeLast();

      currentBlock = savedBlock;
      addStatement(AstFactory.ifStatement2(
        expr,
        // Trampoline the body via Future.wait.
        block([AstFactory.methodInvocation(
            AstFactory.functionExpressionInvocation(
                AstFactory.identifier(identifier('Future'),
                                      identifier('wait')),
                [AstFactory.listLiteral([])]),
            'then',
            [functionExpression([newName('x')], bodyBlock)])]),
        block([AstFactory.functionExpressionInvocation(
            identifier(breakName), [nullLiteral()])])));
    });

    currentBlock = savedBlock;
    addStatement(
        AstFactory.functionDeclarationStatement(null, null, breakName,
            functionExpression([newName('x')], breakBlock)));
    addStatement(
        AstFactory.functionDeclarationStatement(null, null, continueName,
            functionExpression([newName('x')], continueBlock)));
    addStatement(
        AstFactory.functionExpressionInvocation(
            identifier(continueName), [nullLiteral()]));
  };

  visitYieldStatement(ast.YieldStatement node) => unimplemented(node);

  // ---- Expressions ----
  visitAsExpression(ast.AsExpression node) => (f, s) {
    return visit(node.expression)(f, (expr) {
      return s(AstFactory.asExpression(expr, node.type));
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

  visitAssignmentExpression(ast.AssignmentExpression node) => (f, s) {
    finishAssignment(lhs) {
      var nameLeft = node.operator.type != scanner.TokenType.EQ &&
          awaits.contains(node.rightHandSide);
      var lhsValue;
      if (nameLeft) lhsValue = addTempDeclaration(lhs);
      return visit(node.rightHandSide)(f, (rhs) {
        if (nameLeft) {
          return s(AstFactory.assignmentExpression(lhs, scanner.TokenType.EQ,
              AstFactory.binaryExpression(lhsValue,
                  _assignmentToBinaryOperator[node.operator.type],
                  rhs)));
        } else {
          return s(AstFactory.assignmentExpression(lhs,
              node.operator.type, rhs));
        }
      });
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
      return finishAssignment(
          AstFactory.propertyAccess(target, lhs.identifier));
    } else if (lhs is ast.PropertyAccess) {
      return visit(lhs.target)(f, (target) {
        if (awaits.contains(node.rightHandSide)) {
          target = addTempDeclaration(target);
        }
        return finishAssignment(
            AstFactory.propertyAccess(target, lhs.propertyName));
      });
    } else if (lhs is ast.IndexExpression) {
      return visit(lhs.target)(f, (target) {
        if (awaits.contains(lhs.index) ||
            awaits.contains(node.rightHandSide)) {
          target = addTempDeclaration(target);
        }
        return visit(lhs.index)(f, (index) {
          if (awaits.contains(node.rightHandSide)) {
            index = addTempDeclaration(index);
          }
          return finishAssignment(AstFactory.indexExpression(target, index));
        });
      });
    } else {
      throw  'Unexpected ${lhs.runtimeType} in assignment: $lhs';
    }
  };

  visitAwaitExpression(ast.AwaitExpression node) => (f, s) {
    if (awaits.contains(node.expression)) {
      visit(node.expression)(f, (expr) {
        addStatement(
            AstFactory.methodInvocation(
                expr,
                'then',
                [reifyExpressionCont(s, f),
                  AstFactory.namedExpression2('onError', reifyErrorCont(f))]));
      });
    } else {
      addStatement(
          AstFactory.methodInvocation(
              node.expression,
              'then',
              [reifyExpressionCont(s, f),
                AstFactory.namedExpression2('onError', reifyErrorCont(f))]));
    }
  };

  visitBinaryExpression(ast.BinaryExpression node) => (f, s) {
    // TODO: Is this even possible?
    assert(node.operator.lexeme != '||' && node.operator.lexeme != '&&');
    return visit(node.leftOperand)(f, (left) {
      if (awaits.contains(node.rightOperand)) {
        left = addTempDeclaration(left);
      }
      return visit(node.rightOperand)(f, (right) {
        s(AstFactory.binaryExpression(left, node.operator.type, right));
      });
    });
  };

  visitCascadeExpression(ast.CascadeExpression node) => unimplemented(node);

  visitConditionalExpression(ast.ConditionalExpression node) => (f,s) {
    return visit(node.condition)(f, (expr) {
      var joinName = newName('join');
      addStatement(
          AstFactory.functionDeclarationStatement(
              null, null, joinName, reifyErrorCont(s)));
      s = (r) {
        addStatement(AstFactory.methodInvocation2(joinName, [r]));
      };
      var savedBlock = currentBlock;
      var thenBlock = currentBlock = emptyBlock();
      visit(node.thenExpression)(f, s);
      var elseBlock = currentBlock = emptyBlock();
      visit(node.elseExpression)(f, s);
      currentBlock = savedBlock;
      addStatement(AstFactory.ifStatement2(expr, thenBlock, elseBlock));
    });
  };

  visitFunctionExpression(ast.FunctionExpression node) => (f, s) {
    // TODO(kmillikin): Handle async bodies.
    return s(node);
  };

  visitFunctionExpressionInvocation(ast.FunctionExpressionInvocation node) => (f,s) {
    _translateExpressionList(node.argumentList.arguments)(f, (rands) {
          s(AstFactory.functionExpressionInvocation(node.function, rands));
    });
  };

  // ---- Identifiers ----
  visitSimpleIdentifier(ast.SimpleIdentifier node) => (f, s) {
    return s(node);
  };

  visitPrefixedIdentifier(ast.PrefixedIdentifier node) => (f, s) {
    return s(node);
  };

  visitIndexExpression(ast.IndexExpression node) => (f, s) {
    visit(node.target)(f, (e0) {
      if (awaits.contains(node.index)) {
        e0 = addTempDeclaration(e0);
      }
      visit(node.index)(f, (e1) {
        s(AstFactory.indexExpression(e0, e1));
      });
    });
  };

  _translateExpressionList(ast.NodeList<ast.Expression> exprs) => (f, s) {
    if (exprs.isEmpty) {
      return s([]);
    }
    var args = [];
    var seenAwait = false;
    var cont = (v) {
      args.add(v);
      return s(args);
    };
    for (var i = exprs.length - 1; i >= 1; --i) {
      var expr = exprs[i];
      seenAwait = seenAwait || awaits.contains(expr);
      var current = cont;
      if (seenAwait) {
        cont = (v) {
          var value = addTempDeclaration(v);
          args.add(value);
          visit(expr)(f, current);
        };
      } else {
        cont = (v) {
          args.add(v);
          visit(expr)(f, current);
        };
      }
    }
    return visit(exprs.first)(f, cont);
  };

  visitInstanceCreationExpression(
      ast.InstanceCreationExpression node) => (f, s) {
    _translateExpressionList(node.argumentList.arguments)(f, (rands) {
      s(AstFactory.instanceCreationExpression(
              scanner.Keyword.keywords[node.keyword.lexeme],
              node.constructorName,
              rands));
    });
  };

  visitIsExpression(ast.IsExpression node) => (f, s) {
    return visit(node.expression)(f, (expr) {
      return s(AstFactory.isExpression(
          expr, node.notOperator != null, node.type));
    });
  };

  // ---- Literals ----
  visitBooleanLiteral(ast.BooleanLiteral node) => (f, s) {
    s(node);
  };

  visitDoubleLiteral(ast.DoubleLiteral node) => (f, s) {
    s(node);
  };

  visitIntegerLiteral(ast.IntegerLiteral node) => (f, s) {
    s(node);
  };

  visitNullLiteral(ast.NullLiteral node) => (f, s) {
    return s(node);
  };

  // ---- StringLiterals ----
  visitAdjacentStrings(ast.AdjacentStrings node) => unimplemented(node);

  visitSimpleStringLiteral(ast.SimpleStringLiteral node) => (f, s) {
    return s(node);
  };

  visitStringInterpolation(ast.StringInterpolation node) => (f, s) {
    var list = new ast.NodeList<ast.Expression>(node);
    for (var element in node.elements) {
      if (element is ast.InterpolationExpression) {
        list.add(element.expression);
      } else {
        assert(element is ast.InterpolationString);
      }
    }
    _translateExpressionList(list)(f, (exprs) {
      var elements = <ast.InterpolationElement>[];
      int index = 0;
      for (var element in node.elements) {
        if (element is ast.InterpolationExpression) {
          elements.add(AstFactory.interpolationExpression(exprs[index++]));
        } else {
          elements.add(element);
        }
      }
      s(AstFactory.string(elements));
    });
  };

  visitSymbolLiteral(ast.SymbolLiteral node) => (f, s) {
    return s(node);
  };

  // ---- TypedLiterals ----
  visitListLiteral(ast.ListLiteral node) => (f, s) {
    _translateExpressionList(node.elements)(f, (elts) {
      s(AstFactory.listLiteral(elts));
    });
  };

  visitMapLiteral(ast.MapLiteral node) => (f, s) {
    var list = new ast.NodeList<ast.Expression>(node);
    for (var entry in node.entries) {
      list.add(entry.key);
      list.add(entry.value);
    }
    _translateExpressionList(list)(f, (exprs) {
      var entries = <ast.MapLiteralEntry>[];
      for (var i = 0; i < exprs.length; i += 2) {
        entries.add(new ast.MapLiteralEntry(
                exprs[i],
                TokenFactory.tokenFromType(scanner.TokenType.COLON),
                exprs[i + 1]));
      }
      s(AstFactory.mapLiteral2(entries));
    });
  };

  visitMethodInvocation(ast.MethodInvocation node) => (f, s) {
    if (node.target != null) {
      visit(node.target)(f, (rator) {
        if (awaits.contains(node.argumentList)) {
          rator = addTempDeclaration(rator);
        }
        _translateExpressionList(node.argumentList.arguments)(f, (rands) {
          s(AstFactory.methodInvocation(rator, node.methodName.name, rands));
        });
      });
    } else {
      _translateExpressionList(node.argumentList.arguments)(f, (rands) {
        s(AstFactory.methodInvocation2(node.methodName.name, rands));
      });
    }
  };

  visitNamedExpression(ast.NamedExpression node) => (f, s) {
    return visit(node.expression)(f, (expr) {
      return s(AstFactory.namedExpression(node.name, expr));
    });
  };

  visitParenthesizedExpression(ast.ParenthesizedExpression node) => (f, s) {
    return visit(node.expression)(f, s);
  };

  visitPostfixExpression(ast.PostfixExpression node) => unimplemented(node);

  visitPrefixExpression(ast.PrefixExpression node) => (f, s) {
    return visit(node.operand)(f, (expr) {
      return s(AstFactory.prefixExpression(node.operator.type, expr));
    });
  };

  visitPropertyAccess(ast.PropertyAccess node) => (f, s) {
    return visit(node.target)(f, (expr) {
      return s(AstFactory.propertyAccess(expr, node.propertyName));
    });
  };

  visitSuperExpression(ast.SuperExpression node) => (f,s) {
    s(node);
  };

  visitThisExpression(ast.ThisExpression node) => (f,s) {
    s(node);
  };

  visitThrowExpression(ast.ThrowExpression node) => (f, s) {
    return visit(node.expression)(f, (e) => f(e));
  };

  unreachable(node) => throw 'Unreachable(${node.runtimeType})';
  visitAnnotation(node) => unreachable(node);
  visitArgumentList(node) => unreachable(node);
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
