// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library async_await.src.pretty_printer;

import 'package:analyzer/src/generated/ast.dart' as ast;

class PrettyPrinter extends ast.RecursiveAstVisitor {
  final StringBuffer buffer = new StringBuffer();

  int _indent = 0;

  void indent(void action()) {
    buffer.write(' ' * _indent);
    action();
  }

  void withBlockIndentation(void action()) {
    _indent += 2;
    action();
    _indent -= 2;
  }

  void withContinuationIndentation(void action()) {
    _indent += 4;
    action();
    _indent -= 4;
  }

  visit(ast.AstNode node) => node.accept(this);

  visitBlockFunctionBody(ast.BlockFunctionBody node) {
    visit(node.block);
  }

  visitEmptyFunctionBody(ast.EmptyFunctionBody node) {
    buffer.write(';');
  }

  visitExpressionFunctionBody(ast.ExpressionFunctionBody node) {
    buffer.write('=> ');
    visit(node.expression);
  }

  // ---- Statements ----
  // Write the statement to the buffer, including a trailing semicolon if
  // necessary, but no trailing newline or leading indentation.
  visitAssertStatement(ast.AssertStatement node) {
    buffer.write('assert(');
    visit(node.condition);
    buffer.write(');');
  }

  visitBlock(ast.Block node) {
    buffer.writeln('{');
    withBlockIndentation(() {
      for (var statement in node.statements) {
        indent(() { visit(statement); });
        buffer.writeln();
      }
    });
    indent(() { buffer.write('}'); });
  }

  visitBreakStatement(ast.BreakStatement node) {
    buffer.write('break');
    if (node.label != null) {
      buffer.write(' ');
      visit(node.label);
    }
    buffer.write(';');
  }

  visitContinueStatement(ast.ContinueStatement node) {
    buffer.write('continue');
    if (node.label != null) {
      buffer.write(' ');
      visit(node.label);
    }
    buffer.write(';');
  }

  visitDoStatement(ast.DoStatement node) {
    buffer.write('do ');
    visit(node.body);
    buffer.write(' while (');
    visit(node.condition);
    buffer.write(');');
  }

  visitEmptyStatement(ast.EmptyStatement node) {
    buffer.write(';');
  }

  visitExpressionStatement(ast.ExpressionStatement node) {
    visit(node.expression);
    buffer.write(';');
  }

  visitForEachStatement(ast.ForEachStatement node) {
    buffer.write('for (');
    visit(node.identifier != null ? node.identifier : node.loopVariable);
    buffer.write(' in ');
    visit(node.iterator);
    buffer.write(') ');
    visit(node.body);
  }

  visitForStatement(ast.ForStatement node) {
    buffer.write('for (');
    if (node.variables != null) {
      visit(node.variables);
    } else if (node.initialization != null) {
      visit(node.initialization);
    }
    buffer.write(';');
    if (node.condition != null) {
      buffer.write(' ');
      visit(node.condition);
    }
    buffer.write(';');
    if (node.updaters != null) {
      buffer.write(' ');
      visit(node.updaters.first);
      for (var updater in node.updaters.skip(1)) {
        buffer.write(', ');
        visit(updater);
      }
    }
    buffer.write(') ');
    visit(node.body);
  }

  visitFunctionDeclaration(ast.FunctionDeclaration node) {
    if (node.returnType != null) {
      buffer.write(node.returnType);
      buffer.write(' ');
    }
    if (node.propertyKeyword != null) {
      buffer.write(node.propertyKeyword);
      buffer.write(' ');
    }
    visit(node.name);
    visit(node.functionExpression);
  }

  visitFunctionDeclarationStatement(ast.FunctionDeclarationStatement node) {
    visit(node.functionDeclaration);
  }

  visitIfStatement(ast.IfStatement node) {
    buffer.write('if (');
    visit(node.condition);
    buffer.write(') ');
    visit(node.thenStatement);
    if (node.elseStatement != null) {
      buffer.write(' else ');
      visit(node.elseStatement);
    }
  }

  visitLabel(ast.Label node) {
    visit(node.label);
    buffer.write(':');
  }

  visitLabeledStatement(ast.LabeledStatement node) {
    visit(node.labels.first);
    for (var label in node.labels.skip(1)) {
      buffer.write(' ');
      visit(label);
    }
    buffer.write(' ');
    visit(node.statement);
  }

  visitRethrowExpression(ast.RethrowExpression node) {
    buffer.write('rethrow;');
  }

  visitReturnStatement(ast.ReturnStatement node) {
    buffer.write('return');
    if (node.expression != null) {
      buffer.write(' ');
      visit(node.expression);
    }
    buffer.write(';');
  }

  visitSwitchCase(ast.SwitchCase node) {
    if (node.labels.isNotEmpty) {
      visit(node.labels.first);
      for (var label in node.labels.skip(1)) {
        buffer.write(' ');
        visit(label);
      }
    }
    buffer.write('case ');
    visit(node.expression);
    buffer.writeln(':');
    withBlockIndentation(() {
      for (var statement in node.statements) {
        indent(() { visit(statement); });
        buffer.writeln();
      }
    });
  }

  visitSwitchDefault(ast.SwitchDefault node) {
    if (node.labels.isNotEmpty) {
      visit(node.labels.first);
      for (var label in node.labels.skip(1)) {
        buffer.write(' ');
        visit(label);
      }
    }
    buffer.writeln('default:');
    withBlockIndentation(() {
      for (var statement in node.statements) {
        indent(() { visit(statement); });
        buffer.writeln();
      }
    });
  }

  visitSwitchStatement(ast.SwitchStatement node) {
    buffer.write('switch (');
    visit(node.expression);
    buffer.writeln(') {');
    withBlockIndentation(() {
      for (var member in node.members) {
        indent(() { visit(member); });
      }
    });
    indent(() { buffer.write('}'); });
  }

  visitCatchClause(ast.CatchClause node) {
    buffer.write(' ');
    if (node.exceptionType != null) {
      buffer.write('on ');
      buffer.write(node.exceptionType);
      buffer.write(' ');
    }
    if (node.catchKeyword != null) {
      buffer.write('catch (');
      visit(node.exceptionParameter);
      if (node.stackTraceParameter != null) {
        buffer.write(', ');
        visit(node.stackTraceParameter);
      }
      buffer.write(') ');
    }
    visit(node.body);
  }

  visitTryStatement(ast.TryStatement node) {
    buffer.write('try ');
    visit(node.body);
    for (var clause in node.catchClauses) {
      visit(clause);
    }
    if (node.finallyBlock != null) {
      buffer.write(' finally ');
      visit(node.finallyBlock);
    }
  }

  visitVariableDeclaration(ast.VariableDeclaration node) {
    visit(node.name);
    if (node.initializer != null) {
      buffer.write(' = ');
      visit(node.initializer);
    }
  }

  visitVariableDeclarationList(ast.VariableDeclarationList node) {
    if (node.keyword != null){
      buffer.write(node.keyword);
      buffer.write(' ');
    }
    if (node.type != null) {
      buffer.write(node.type);
      buffer.write(' ');
    }
    visit(node.variables.first);
    withContinuationIndentation(() {
      for (var variable in node.variables.skip(1)) {
        buffer.writeln(',');
        indent(() { visit(variable); });
      }
    });
  }

  visitVariableDeclarationStatement(ast.VariableDeclarationStatement node) {
    visit(node.variables);
    buffer.write(';');
  }

  visitWhileStatement(ast.WhileStatement node) {
    buffer.write('while (');
    visit(node.condition);
    buffer.write(') ');
    visit(node.body);
  }

  visitYieldStatement(ast.YieldStatement node) {
    buffer.write('yield ');
    visit(node.expression);
    buffer.write(';');
  }

  // ---- Expressions ----
  visitArgumentList(ast.ArgumentList node) {
    buffer.write('(');
    if (node.arguments.isNotEmpty) {
      visit(node.arguments.first);
      for (var argument in node.arguments.skip(1)) {
        buffer.write(', ');
        visit(argument);
      }
    }
    buffer.write(')');
  }

  visitAsExpression(ast.AsExpression node) {
    visit(node.expression);
    buffer.write(' as ');
    visit(node.type);
  }

  visitAssignmentExpression(ast.AssignmentExpression node) {
    visit(node.leftHandSide);
    buffer.write(' ');
    buffer.write(node.operator.lexeme);
    buffer.write(' ');
    visit(node.rightHandSide);
  }

  visitAwaitExpression(ast.AwaitExpression node) {
    buffer.write('await ');
    visit(node.expression);
  }

  visitBinaryExpression(ast.BinaryExpression node) {
    visit(node.leftOperand);
    buffer.write(' ');
    buffer.write(node.operator.lexeme);
    buffer.write(' ');
    visit(node.rightOperand);
  }

  visitCascadeExpression(ast.CascadeExpression node) {
    visit(node.target);
    withContinuationIndentation(() {
      for (var section in node.cascadeSections) {
        buffer.writeln();
        indent(() {
          buffer.write('..');
          visit(section);
        });
      }
    });
  }

  visitConditionalExpression(ast.ConditionalExpression node) {
    visit(node.condition);
    withContinuationIndentation(() {
      buffer.writeln();
      indent(() {
        buffer.write('? ');
        visit(node.thenExpression);
      });
      buffer.writeln();
      indent(() {
        buffer.write(': ');
        visit(node.elseExpression);
      });
    });
  }

  visitConstructorName(ast.ConstructorName node) {
    visit(node.type);
    if (node.name != null) {
      buffer.write('.');
      visit(node.name);
    }
  }

  visitTypeName(ast.TypeName node) {
    visit(node.name);
    if (node.typeArguments != null) buffer.write(node.typeArguments);
  }

  visitFunctionExpression(ast.FunctionExpression node) {
    buffer.write(node.parameters);
    if (node.body is! ast.EmptyFunctionBody) buffer.write(' ');
    visit(node.body);
  }

  visitFunctionExpressionInvocation(ast.FunctionExpressionInvocation node) {
    visit(node.function);
    visit(node.argumentList);
  }

  // ---- Identifiers ----
  visitSimpleIdentifier(ast.SimpleIdentifier node) {
    buffer.write(node);
  }

  visitPrefixedIdentifier(ast.PrefixedIdentifier node) {
    buffer.write(node);
  }

  visitIndexExpression(ast.IndexExpression node) {
    if (node.target != null) {
      visit(node.target);
    }
    buffer.write('[');
    visit(node.index);
    buffer.write(']');
  }

  visitConstructorName(ast.ConstructorName node) {
    buffer.write(node);
  }

  visitInstanceCreationExpression(ast.InstanceCreationExpression node) {
    buffer.write(node.keyword);
    buffer.write(' ');
    visit(node.constructorName);
    visit(node.argumentList);
  }

  visitIsExpression(ast.IsExpression node) {
    visit(node.expression);
    buffer.write(node.notOperator != null ? ' is! ' : ' is ');
    visit(node.type);
  }

  // ---- Literals ----
  visitBooleanLiteral(ast.BooleanLiteral node) {
    buffer.write(node);
  }

  visitDoubleLiteral(ast.DoubleLiteral node) {
    buffer.write(node);
  }

  visitIntegerLiteral(ast.IntegerLiteral node) {
    buffer.write(node);
  }

  visitNullLiteral(ast.NullLiteral node) {
    buffer.write('null');
  }

  // ---- StringLiterals ----
  visitAdjacentStrings(ast.AdjacentStrings node) {
    visit(node.strings.first);
    withContinuationIndentation(() {
      for (var string in node.strings.skip(1)) {
        buffer.writeln();
        indent(() { visit(string); });
      }
    });
  }

  visitSimpleStringLiteral(ast.SimpleStringLiteral node) {
    buffer.write(node);
  }

  visitInterpolationExpression(ast.InterpolationExpression node) {
    buffer.write('\$');
    if (node.rightBracket != null) {
      buffer.write('{');
      visit(node.expression);
      buffer.write('}');
    } else {
      visit(node.expression);
    }
  }

  visitInterpolationString(ast.InterpolationString node) {
    buffer.write(node);
  }

  visitStringInterpolation(ast.StringInterpolation node) {
    for (var element in node.elements) {
      visit(element);
    }
  }

  visitSymbolLiteral(ast.SymbolLiteral node) {
    buffer.write(node);
  }

  // ---- TypedLiterals ----
  visitListLiteral(ast.ListLiteral node) {
    if (node.constKeyword != null) {
      buffer.write(node.constKeyword.lexeme);
      buffer.write(' ');
    }
    if (node.typeArguments != null) {
      buffer.write(node.typeArguments);
    }
    buffer.write('[');
    if (node.elements.isEmpty) {
      buffer.write(']');
    } else {
      withContinuationIndentation(() {
        buffer.writeln();
        indent(() { visit(node.elements.first); });
        for (var element in node.elements.skip(1)) {
          buffer.writeln(',');
          indent(() { visit(element); });
        }
      });
      buffer.writeln();
      indent(() { buffer.write(']'); });
    }
  }

  visitMapLiteralEntry(ast.MapLiteralEntry node) {
    visit(node.key);
    buffer.write(': ');
    visit(node.value);
  }

  visitMapLiteral(ast.MapLiteral node) {
    if (node.constKeyword != null) {
      buffer.write(node.constKeyword.lexeme);
      buffer.write(' ');
    }
    if (node.typeArguments != null) {
      buffer.write(node.typeArguments);
    }
    buffer.write('{');
    if (node.entries.isEmpty) {
      buffer.write('}');
    } else {
      withContinuationIndentation(() {
        buffer.writeln();
        indent(() { visit(node.entries.first); });
        for (var entry in node.entries.skip(1)) {
          buffer.writeln(',');
          indent(() { visit(entry); });
        }
      });
      buffer.writeln();
      indent(() { buffer.write('}'); });
    }
  }

  visitMethodInvocation(ast.MethodInvocation node) {
    if (node.target != null) {
      visit(node.target);
      buffer.write('.');
    }
    visit(node.methodName);
    visit(node.argumentList);
  }

  visitNamedExpression(ast.NamedExpression node) {
    visit(node.name);
    buffer.write(' ');
    visit(node.expression);
  }

  visitParenthesizedExpression(ast.ParenthesizedExpression node) {
    buffer.write('(');
    visit(node.expression);
    buffer.write(')');
  }

  visitPostfixExpression(ast.PostfixExpression node) {
    visit(node.operand);
    buffer.write(node.operator.lexeme);
  }

  visitPrefixExpression(ast.PrefixExpression node) {
    buffer.write(node.operator.lexeme);
    visit(node.operand);
  }

  visitPropertyAccess(ast.PropertyAccess node) {
    if (node.target != null) {
      visit(node.target);
      buffer.write('.');
    }
    visit(node.propertyName);
  }

  visitSuperExpression(ast.SuperExpression node) {
    buffer.write('super');
  }

  visitThisExpression(ast.ThisExpression node) {
    buffer.write('this');
  }

  visitThrowExpression(ast.ThrowExpression node) {
    buffer.write('throw ');
    buffer.write(node.expression);
  }
}
