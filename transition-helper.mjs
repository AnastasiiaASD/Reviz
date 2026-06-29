#!/usr/bin/env node
// Bypass jira-ai CLI's "Multiple transitions found" limitation.
// Usage: node transition-helper.mjs <task-id> <to-status>
const GLOBAL_MODULES = '/usr/local/lib/node_modules';
const { getIssueTransitions, transitionIssue, validateIssuePermissions } =
  await import(`file://${GLOBAL_MODULES}/jira-ai/dist/lib/jira-client.js`);

const [taskId, toStatus] = process.argv.slice(2);
if (!taskId || !toStatus) {
  console.error('Usage: node transition-helper.mjs <task-id> <to-status>');
  process.exit(1);
}

try {
  await validateIssuePermissions(taskId, 'transition');
  const transitions = await getIssueTransitions(taskId);

  console.log('Available transitions:');
  transitions.forEach(t => console.log(`  "${t.name}" (ID: ${t.id}) → ${t.to.name}`));

  const match = transitions.find(t => t.to.name.toLowerCase() === toStatus.toLowerCase());
  if (!match) {
    const available = [...new Set(transitions.map(t => t.to.name))].join(', ');
    console.error(`No transition to "${toStatus}". Available: ${available}`);
    process.exit(1);
  }

  console.log(`Using transition "${match.name}" (ID: ${match.id}) → ${match.to.name}`);
  await transitionIssue(taskId, match.id);
  console.log(`Done: ${taskId} → ${match.to.name}`);
} catch (err) {
  console.error(`Transition failed: ${err.message}`);
  process.exit(1);
}
