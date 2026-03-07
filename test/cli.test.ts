import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as child_process from 'child_process';
import { JCLAW } from '../src/index.js';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';

vi.mock('child_process', () => {
  return {
    exec: vi.fn((...args: any[]) => {
      const callback = args[args.length - 1];
      // Basic mock implementation for promisify(exec)
      if (typeof callback === 'function') {
        callback(null, { stdout: 'mocked output', stderr: '' });
      }
      return { stdout: 'mocked output', stderr: '' };
    })
  };
});

describe('CLI Tier Tests', () => {
  let mcp: any;
  const tempDir = path.join(os.tmpdir(), 'jclaw-test-cli');

  beforeEach(async () => {
    vi.stubEnv('NODE_ENV', 'test');
    vi.stubEnv('JULES_DATA_PATH', path.join(tempDir, 'data.json'));

    await fs.mkdir(tempDir, { recursive: true });

    mcp = new JCLAW();
  });

  afterEach(async () => {
    vi.restoreAllMocks();
    vi.unstubAllEnvs();
    await fs.rm(tempDir, { recursive: true, force: true });
  });

  it('jules_cli executes command', async () => {
    const execMock = vi.mocked(child_process.exec);
    execMock.mockImplementation((...args: any[]) => {
      const callback = args[args.length - 1];
      if (typeof callback === 'function') {
         callback(null, { stdout: 'jules version 1.0.0', stderr: '' });
      }
      return {} as any;
    });

    const result = await mcp.runJulesCli(['version']);
    expect(result).toBe('jules version 1.0.0');
    expect(execMock).toHaveBeenCalled();
    const callArgs = execMock.mock.calls[execMock.mock.calls.length - 1][0] as string;
    expect(callArgs).toContain('version');
  });

  it('jules_create_task via CLI parses output for session ID', async () => {
    const execMock = vi.mocked(child_process.exec);
    execMock.mockImplementation((...args: any[]) => {
      const callback = args[args.length - 1];
      if (typeof callback === 'function') {
         // Simulate typical output with session ID
         // Using hex characters that match [a-f0-9-] logic in parsing
         callback(null, { stdout: 'Created session: a1b2c3d4e5f6\nStarting task...', stderr: '' });
      }
      return {} as any;
    });

    const result = await mcp.createTaskViaCli({
      description: 'Test task',
      repository: 'test/repo'
    });

    expect(result.taskId).toBe('a1b2c3d4e5f6');
    expect(result.task.repository).toBe('test/repo');
    expect(result.content[0].text).toContain('a1b2c3d4e5f6');
  });

  it('jules_delegate_task pushes branch and initiates task', async () => {
     const execMock = vi.mocked(child_process.exec);
     execMock.mockImplementation((...args: any[]) => {
      const cmd = args[0];
      const callback = args[args.length - 1];
      if (typeof callback === 'function') {
         // Mock git and jules CLI output
         if (cmd.includes('git push')) {
             callback(null, { stdout: 'Everything up-to-date', stderr: '' });
         } else if (cmd.includes('jules')) {
             callback(null, { stdout: 'Created session: a1b2c3d4e5f6g7h8', stderr: '' });
         } else {
             callback(null, { stdout: '', stderr: '' });
         }
      }
      return {} as any;
    });

    // Mock createTaskViaApi/Cli since initiateDelegation delegates to them
    mcp.createTaskViaCli = vi.fn().mockResolvedValue({ taskId: 'mocked-task-id' });
    mcp.runGitCommand = vi.fn().mockResolvedValue('success');

    const result = await mcp.initiateDelegation({
      repository: 'test/repo',
      branch: 'feature-branch',
      pushFirst: true
    });

    expect(mcp.runGitCommand).toHaveBeenCalledWith(['push', 'origin', 'feature-branch']);
    expect(mcp.createTaskViaCli).toHaveBeenCalledWith(
        expect.objectContaining({
            type: 'delegated',
            repository: 'test/repo'
        })
    );
    expect(result.content[0].text).toContain('Results [Delegation]:');
    expect(result.content[0].text).toContain('Pushed feature-branch');
  });
});
