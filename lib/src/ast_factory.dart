// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library async_await.src.ast_factory;

import 'package:analyzer/src/generated/ast.dart' as ast;
import 'package:analyzer/src/generated/scanner.dart' as scanner;
import 'package:analyzer/src/generated/testing/ast_factory.dart';

// AST construction functions.
scanner.Keyword keyword(scanner.Token token) {
  if (token == null) return null;
  return scanner.Keyword.keywords[token.lexeme];
}

// Create a function body from an expression, a single statement, or a block.
ast.FunctionBody functionBody(ast.AstNode body) {
  if (body is ast.Expression) {
    return AstFactory.expressionFunctionBody(body);
  }
  assert(body is ast.Statement);
  if (body is! ast.Block) body = block([body]);
  return AstFactory.blockFunctionBody(body);
}

// Create a function expression from a list of parameter names and an
// expression, single statement, or block.
ast.FunctionExpression functionExpression(List<String> parameters,
                                          ast.AstNode body) {
  var formalParameters = AstFactory.formalParameterList(
      parameters.map(AstFactory.simpleFormalParameter3).toList());
  return AstFactory.functionExpression2(formalParameters, functionBody(body));
}

ast.CatchClause catchClause(ast.TypeName exceptionType, exceptionParameter,
                            stackTraceParameter, statements) {
  if (exceptionParameter is ast.SimpleIdentifier) {
    exceptionParameter = exceptionParameter.name;
  }
  if (stackTraceParameter is ast.SimpleIdentifier) {
    stackTraceParameter = stackTraceParameter.name;
  }
  if (statements is ast.Block) {
    statements = statements.statements;
  }
  return AstFactory.catchClause5(exceptionType, exceptionParameter,
      stackTraceParameter, statements);
}

ast.SwitchMember switchCase(ast.Expression expression,
                            List<ast.Statement> statements) {
  return expression == null
      ? AstFactory.switchDefault2(statements)
      : AstFactory.switchCase(expression, statements);
}

// --- Statements ----
ast.AssertStatement assertStatement(ast.Expression condition) {
  return AstFactory.assertStatement(condition);
}

// Create a block from a list of expressions and statements.
ast.Block block(List<ast.AstNode> body) {
  var statements = body.map((node) {
    if (node is ast.Expression){
      return expressionStatement(node);
    } else {
      assert(node is ast.Statement);
      return node;
    }
  }).toList();
  return AstFactory.block(statements);
}

ast.Block emptyBlock() {
  return block([]);
}

ast.BreakStatement breakStatement() {
  return AstFactory.breakStatement();
}

ast.DoStatement doStatement(ast.Statement body, ast.Expression condition) {
  return AstFactory.doStatement(body, condition);
}

ast.ExpressionStatement expressionStatement(ast.Expression expression) {
  return AstFactory.expressionStatement(expression);
}

ast.FunctionDeclarationStatement functionDeclarationStatement(String name,
    List<String> parameters, ast.AstNode body) {
  return AstFactory.functionDeclarationStatement(null,  null,  name,
      functionExpression(parameters, body));
}

// Create an if/then/else with an optional else part.
ast.IfStatement ifStatement(ast.Expression condition,
                            ast.Statement thenStatement,
                            [ast.Statement elseStatement]) {
  return elseStatement == null
      ? AstFactory.ifStatement(condition, thenStatement)
      : AstFactory.ifStatement2(condition, thenStatement, elseStatement);
}

// Create a return with an optional expression.  If the expression is omitted
// then explicit `return null` is created to ensure that there are no
// warnings when return with a value and return with no value are mixed in the
// same function.
ast.ReturnStatement returnStatement([ast.Expression expr]) {
  return AstFactory.returnStatement2(expr == null
      ? nullLiteral()
      : expr);
}

ast.SwitchStatement switchStatement(ast.Expression expression,
                                    List<ast.SwitchMember> members) {
  return AstFactory.switchStatement(expression, members);
}

ast.TryStatement tryStatement(body, List<ast.CatchClause> catchClauses) {
  if (body is! ast.Block) {
    assert(body is List);
    body = block(body);
  }
  return AstFactory.tryStatement2(body, catchClauses);
}

ast.VariableDeclaration variableDeclaration(String name,
                                            [ast.Expression initializer]) {
  return initializer == null
      ? AstFactory.variableDeclaration(name)
      : AstFactory.variableDeclaration2(name, initializer);
}

ast.VariableDeclarationStatement variableDeclarationStatement(
      scanner.Keyword keyword,
      List<ast.VariableDeclaration> declarations,
      [ast.TypeName type]) {
  return AstFactory.variableDeclarationStatement(keyword, type, declarations);
}

ast.WhileStatement whileStatement(ast.Expression condition,
                                  ast.Statement body) {
  return AstFactory.whileStatement(condition, body);
}

// ---- Expressions ----
ast.AdjacentStrings adjacentStrings(List<ast.StringLiteral> strings) {
  return AstFactory.adjacentStrings(strings);
}

ast.AsExpression asExpression(ast.Expression expression, ast.TypeName type) {
  return AstFactory.asExpression(expression, type);
}

ast.AssignmentExpression assignmentExpression(ast.Expression leftHandSide,
    ast.Expression rightHandSide,
    [scanner.TokenType operator = scanner.TokenType.EQ]) {
  return AstFactory.assignmentExpression(leftHandSide, operator, rightHandSide);
}

ast.BinaryExpression binaryExpression(ast.Expression leftOperand,
      scanner.TokenType operator, ast.Expression rightOperand) {
  return AstFactory.binaryExpression(leftOperand, operator, rightOperand);
}

ast.BooleanLiteral booleanLiteral(bool value) {
  return AstFactory.booleanLiteral(value);
}

ast.Expression cascadeSection(ast.Expression expression) {
  if (expression is ast.IndexExpression) {
    return AstFactory.cascadedIndexExpression(expression.index);
  } else if (expression is ast.MethodInvocation) {
    return AstFactory.cascadedMethodInvocation(expression.methodName.name,
        expression.argumentList.arguments);
  } else if (expression is ast.PropertyAccess) {
    return AstFactory.cascadedPropertyAccess(expression.propertyName.name);
  } else if (expression is ast.AssignmentExpression) {
    return assignmentExpression(cascadeSection(expression.leftHandSide),
        expression.rightHandSide, expression.operator.type);
  }
  throw 'Unexpected expression $expression in cascade';
}

ast.CascadeExpression cascadeExpression(ast.Expression target,
                                        List<ast.Expression> cascadeSections) {
  return AstFactory.cascadeExpression(target, cascadeSections);
}

ast.ConditionalExpression conditionalExpression(ast.Expression condition,
                                                ast.Expression ifTrue,
                                                ast.Expression ifFalse) {
  return AstFactory.conditionalExpression(condition, ifTrue, ifFalse);
}

// Create a function invocation.  The function can be a string for the common
// case of invoking a named function, otherwise it is expected to be an
// expression.  The argument list is optional, to support concise creation of
// invocations of no-argument functions.
ast.FunctionExpressionInvocation functionInvocation(function,
    [List<ast.Expression> arguments]) {
  if (function is String) function = identifier(function);
  assert(function is ast.Expression);
  return AstFactory.functionExpressionInvocation(function,
      arguments == null ? [] : arguments);
}

// Create an optionally qualified identifier.
ast.Identifier identifier(String first, [String second]) {
  return second == null
      ? AstFactory.identifier3(first)
      : AstFactory.identifier5(first, second);
}

ast.IndexExpression indexExpression(ast.Expression target,
                                    ast.Expression index) {
  return AstFactory.indexExpression(target, index);
}

ast.IsExpression isExpression(ast.Expression expression,
    bool negated, ast.TypeName typeName) {
  return AstFactory.isExpression(expression, negated, typeName);
}

ast.ListLiteral listLiteral(List<ast.Expression> elements) {
  return AstFactory.listLiteral(elements);
}

ast.MapLiteral mapLiteral(List<ast.MapLiteralEntry> entries) {
  return AstFactory.mapLiteral2(entries);
}

ast.MethodInvocation methodInvocation(ast.Expression target, String name,
                                      List<ast.Expression> arguments) {
  return AstFactory.methodInvocation(target, name, arguments);
}

ast.NamedExpression namedExpression(label, ast.Expression expression) {
  return label is String
      ? AstFactory.namedExpression2(label, expression)
      : AstFactory.namedExpression(label, expression);
}

ast.InstanceCreationExpression newInstance(ast.AstNode constructor,
    List<ast.Expression> arguments,
    [scanner.Keyword keyword = scanner.Keyword.NEW]) {
  if (constructor is ast.ConstructorName) {
    return AstFactory.instanceCreationExpression(
        keyword, constructor, arguments);
  } else {
    assert(constructor is ast.Identifier);
    return AstFactory.instanceCreationExpression2(
        keyword, AstFactory.typeName3(constructor, []), arguments);
  }
}

ast.NullLiteral nullLiteral() {
  return AstFactory.nullLiteral();
}

ast.ParenthesizedExpression parenthesizedExpression(
    ast.Expression expression) {
  return AstFactory.parenthesizedExpression(expression);
}

ast.PostfixExpression postfixExpression(ast.Expression expression,
                                        scanner.TokenType operator) {
  return AstFactory.postfixExpression(expression, operator);
}

ast.PrefixExpression prefixExpression(scanner.TokenType operator,
                                      ast.Expression expression) {
  return AstFactory.prefixExpression(operator, expression);
}

ast.PropertyAccess propertyAccess(ast.Expression target, propertyName) {
  if (propertyName is String) propertyName = identifier(propertyName);
  return AstFactory.propertyAccess(target, propertyName);
}

ast.InterpolationExpression interpolationExpression(
    ast.Expression expression) {
  return AstFactory.interpolationExpression(expression);
}

ast.StringInterpolation stringInterpolation(
    List<ast.InterpolationElement> elements) {
  return AstFactory.string(elements);
}

ast.ThrowExpression throwExpression(ast.Expression expression) {
  return AstFactory.throwExpression2(expression);
}
