import { describe, it, expect, vi, beforeEach } from 'vitest';
import * as child_process from 'child_process';
import { JCLAW } from '../src/index.js';

vi.mock('child_process', () => {
  return {
    exec: vi.fn(),
    execFile: vi.fn(),
  };
});

describe('Security Vulnerability Fix Verification', () => {
  let mcp: any;

  beforeEach(() => {
    vi.clearAllMocks();
    mcp = new JCLAW();
  });

  it('runGhCommand uses execFile safely', async () => {
    const execFileMock = vi.mocked(child_process.execFile);
    execFileMock.mockImplementation((file: string, args: any, callback: any) => {
      if (typeof callback === 'function') {
        callback(null, { stdout: 'mocked output', stderr: '' });
      }
      return {} as any;
    });

    const maliciousArgs = ['api', 'repos/owner/repo; touch vulnerability.txt'];
    await mcp.runGhCommand(maliciousArgs);

    expect(execFileMock).toHaveBeenCalled();
    const file = execFileMock.mock.calls[0][0];
    const args = execFileMock.mock.calls[0][1];

    expect(file).toBe('gh');
    expect(args).toEqual(['api', 'repos/owner/repo; touch vulnerability.txt']);
    // Since it's passed as an array to execFile, the semicolon will be treated as part of the argument, not a shell command separator.
  });

  it('runGitCommand uses execFile safely', async () => {
    const execFileMock = vi.mocked(child_process.execFile);
    execFileMock.mockImplementation((file: string, args: any, callback: any) => {
      if (typeof callback === 'function') {
        callback(null, { stdout: 'mocked output', stderr: '' });
      }
      return {} as any;
    });

    const maliciousArgs = ['checkout', 'main; touch git_vulnerability.txt'];
    await mcp.runGitCommand(maliciousArgs);

    expect(execFileMock).toHaveBeenCalled();
    expect(execFileMock.mock.calls[0][0]).toBe('git');
    expect(execFileMock.mock.calls[0][1]).toEqual([
      'checkout',
      'main; touch git_vulnerability.txt',
    ]);
  });

  it('runJulesCli uses execFile and no longer needs manual escaping or shell redirection', async () => {
    const execFileMock = vi.mocked(child_process.execFile);
    execFileMock.mockImplementation((file: string, args: any, callback: any) => {
      if (typeof callback === 'function') {
        callback(null, { stdout: 'mocked output', stderr: '' });
      }
      return {} as any;
    });

    // Mock resolveJulesCliPath to avoid actually running which/where
    mcp.resolveJulesCliPath = vi.fn().mockResolvedValue('/usr/local/bin/jules');

    const maliciousArgs = ['remote', 'new', '--session', 'Exploit`touch jules_vulnerability.txt`'];
    await mcp.runJulesCli(maliciousArgs);

    expect(execFileMock).toHaveBeenCalled();
    expect(execFileMock.mock.calls[0][0]).toBe('/usr/local/bin/jules');
    expect(execFileMock.mock.calls[0][1]).toEqual([
      'remote',
      'new',
      '--session',
      'Exploit`touch jules_vulnerability.txt`',
    ]);
    // manual escaping and < /dev/null should be gone
  });
});
