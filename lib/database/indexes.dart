/// Индексы базы данных: имя -> SQL создания.
/// Хранятся в одном месте, чтобы тест производительности мог их
/// удалять и создавать заново.
const Map<String, String> kIndexes = {
  'idx_tasks_project':
      'CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks (project_id)',
  'idx_tasks_assignee':
      'CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks (assignee_id)',
  'idx_tasks_status':
      'CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks (status)',
  'idx_tasks_priority':
      'CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks (priority)',
  'idx_tasks_deadline':
      'CREATE INDEX IF NOT EXISTS idx_tasks_deadline ON tasks (deadline)',
  'idx_tasks_created':
      'CREATE INDEX IF NOT EXISTS idx_tasks_created ON tasks (created_at)',
  'idx_tasks_deleted':
      'CREATE INDEX IF NOT EXISTS idx_tasks_deleted ON tasks (deleted_at)',
  'idx_tasks_assignee_deadline':
      'CREATE INDEX IF NOT EXISTS idx_tasks_assignee_deadline ON tasks (assignee_id, deadline)',
  'idx_members_user':
      'CREATE INDEX IF NOT EXISTS idx_members_user ON project_members (user_id)',
  'idx_comments_task':
      'CREATE INDEX IF NOT EXISTS idx_comments_task ON comments (task_id)',
  'idx_attachments_task':
      'CREATE INDEX IF NOT EXISTS idx_attachments_task ON attachments (task_id)',
  'idx_history_task':
      'CREATE INDEX IF NOT EXISTS idx_history_task ON task_history (task_id)',
};
