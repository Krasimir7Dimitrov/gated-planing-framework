#!/bin/bash

INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
if [ -z "$FILE" ]; then
  FILE=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
fi

FILE_NORM=$(echo "$FILE" | tr '\\' '/')

if [[ "$FILE_NORM" != *"research-problems.md"* ]]; then
  exit 0
fi

if [ ! -f ".claude/research-problems.md" ]; then
  exit 0
fi

# Read only the ## Problem: sections (skip comment lines starting with #)
PROBLEM_TEXT=$(grep -v '^#' .claude/research-problems.md)

# Check 1: PHP syntax - unambiguous sign of implementation-level thinking
PHP_SYNTAX=$(echo "$PROBLEM_TEXT" | grep -E '\$[a-zA-Z_]|->|::|[a-zA-Z]\w*\(|{}')

if [ -n "$PHP_SYNTAX" ]; then
  echo "X BLOCKED: .claude/research-problems.md contains PHP syntax." >&2
  echo "" >&2
  echo "  Problem statements must describe WHAT is needed in plain language." >&2
  echo "  No \$variables, ->, ::, or method() calls allowed." >&2
  echo "" >&2
  echo "  Found:" >&2
  echo "$PHP_SYNTAX" | while IFS= read -r line; do
    echo "  * $line" >&2
  done
  echo "" >&2
  echo "  Rewrite without any PHP syntax - describe the outcome, not the implementation." >&2
  exit 2
fi

# Check 2: Symfony/Doctrine class names used as specific implementation references
CLASS_NAMES=$(echo "$PROBLEM_TEXT" | grep -iE '\b(EventDispatcher|EntityManagerInterface|EventDispatcherInterface|EventSubscriberInterface|DoctrineEventSubscriber|UnitOfWork|LifecycleEventArgs|FlushEventArgs|EntityRepository|ServiceLocator|ContainerInterface|Interface|LoggerInterface|ParameterBagInterface)\b')

if [ -n "$CLASS_NAMES" ]; then
  echo "X BLOCKED: .claude/research-problems.md contains framework class names." >&2
  echo "" >&2
  echo "  Problem statements must not name specific classes or interfaces." >&2
  echo "  The researcher must discover these independently." >&2
  echo "" >&2
  echo "  Found: $CLASS_NAMES" >&2
  echo "" >&2
  echo "  Replace with plain language - e.g. instead of 'EventDispatcher' write 'a mechanism that decouples the caller from the action'." >&2
  exit 2
fi

# Check 3: Implementation action verbs and pattern names
IMPL_VERBS=$(echo "$PROBLEM_TEXT" | grep -iE '\b(inject|dispatch|autowire|bind|persist|subscribe|listen|event|event-based|event-driven|observer pattern|spec|sub|decouple|publish-subscribe|listen|dispatcher)\b')

if [ -n "$IMPL_VERBS" ]; then
  echo "X BLOCKED: .claude/research-problems.md contains implementation or pattern-hint language." >&2
  echo "" >&2
  echo "  Words like 'inject', 'dispatch', 'listener', 'subscriber', 'event-based', 'decouple', 'observer pattern'" >&2
  echo "  describe HOW (a mechanism), not WHAT (a business outcome)." >&2
  echo "" >&2
  echo "  Found:" >&2
  echo "$IMPL_VERBS" | while IFS= read -r line; do
    echo "  * $line" >&2
  done
  echo "" >&2
  echo "  Self-check: would a developer without Symfony knowledge understand what business outcome is needed?" >&2
  echo "  If not - rewrite until the answer is YES." >&2
  exit 2
fi