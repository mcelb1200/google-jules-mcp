import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { JCLAW } from '../src/index.js';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';

describe('Task Management Tests', () => {
  let mcp: any;
  const tempDir = path.join(os.tmpdir(), 'jclaw-test-tasks');
  const dataPath = path.join(tempDir, 'data.json');

  beforeEach(async () => {
    vi.stubEnv('NODE_ENV', 'test');
    vi.stubEnv('JULES_DATA_PATH', dataPath);

    await fs.mkdir(tempDir, { recursive: true });

    mcp = new JCLAW();
  });

  afterEach(async () => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
    await fs.rm(tempDir, { recursive: true, force: true });
  });

  it('getActiveTasks filters tasks correctly', async () => {
    const mockTasks = [
      { id: '1', title: 'Task 1', status: 'pending', repository: 'repo1', branch: 'main', type: 'standard', createdAt: '', updatedAt: '', url: '', chatHistory: [], sourceFiles: [] },
      { id: '2', title: 'Task 2', status: 'in_progress', repository: 'repo1', branch: 'main', type: 'standard', createdAt: '', updatedAt: '', url: '', chatHistory: [], sourceFiles: [] },
      { id: '3', title: 'Task 3', status: 'completed', repository: 'repo1', branch: 'main', type: 'standard', createdAt: '', updatedAt: '', url: '', chatHistory: [], sourceFiles: [] },
      { id: '4', title: 'Task 4', status: 'paused', repository: 'repo1', branch: 'main', type: 'standard', createdAt: '', updatedAt: '', url: '', chatHistory: [], sourceFiles: [] },
    ];

    await fs.writeFile(dataPath, JSON.stringify({ tasks: mockTasks }));

    const activeTasks = await (mcp as any).getActiveTasks();

    expect(activeTasks).toHaveLength(2);
    expect(activeTasks.map((t: any) => t.id)).toContain('1');
    expect(activeTasks.map((t: any) => t.id)).toContain('2');
    expect(activeTasks.map((t: any) => t.id)).not.toContain('3');
    expect(activeTasks.map((t: any) => t.id)).not.toContain('4');
  });

  it('getActiveTasks returns empty array when no tasks exist', async () => {
    await fs.writeFile(dataPath, JSON.stringify({ tasks: [] }));

    const activeTasks = await (mcp as any).getActiveTasks();

    expect(activeTasks).toEqual([]);
  });

  it('getActiveTasks returns empty array when file does not exist', async () => {
    // dataPath is not created yet
    const activeTasks = await (mcp as any).getActiveTasks();
    expect(activeTasks).toEqual([]);
  });
});
