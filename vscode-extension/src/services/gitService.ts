import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export class GitService {
  private workspacePath: string;

  constructor(workspacePath?: string) {
    this.workspacePath = workspacePath || process.cwd();
  }

  async init(): Promise<void> {
    try {
      await execAsync('git init', { cwd: this.workspacePath });
    } catch (error) {
      throw new Error(`Failed to initialize git repository: ${error}`);
    }
  }

  async clone(repoUrl: string, targetPath: string): Promise<void> {
    try {
      await execAsync(`git clone "${repoUrl}" "${targetPath}"`);
    } catch (error) {
      throw new Error(`Failed to clone repository: ${error}`);
    }
  }

  async add(files: string[] = ['.']): Promise<void> {
    try {
      const fileList = files.join(' ');
      await execAsync(`git add ${fileList}`, { cwd: this.workspacePath });
    } catch (error) {
      throw new Error(`Failed to add files: ${error}`);
    }
  }

  async commit(message: string): Promise<void> {
    try {
      await execAsync(`git commit -m "${message}"`, { cwd: this.workspacePath });
    } catch (error) {
      // Check if there are changes to commit
      const { stdout } = await execAsync('git status --porcelain', { cwd: this.workspacePath });
      if (!stdout.trim()) {
        throw new Error('No changes to commit');
      }
      throw new Error(`Failed to commit: ${error}`);
    }
  }

  async push(remote: string = 'origin', branch: string = 'main'): Promise<void> {
    try {
      await execAsync(`git push ${remote} ${branch}`, { cwd: this.workspacePath });
    } catch (error) {
      throw new Error(`Failed to push: ${error}`);
    }
  }

  async pull(remote: string = 'origin', branch: string = 'main'): Promise<void> {
    try {
      await execAsync(`git pull ${remote} ${branch}`, { cwd: this.workspacePath });
    } catch (error) {
      throw new Error(`Failed to pull: ${error}`);
    }
  }

  async status(): Promise<string> {
    try {
      const { stdout } = await execAsync('git status --porcelain', { cwd: this.workspacePath });
      return stdout;
    } catch (error) {
      throw new Error(`Failed to get status: ${error}`);
    }
  }

  async log(limit: number = 10): Promise<string> {
    try {
      const { stdout } = await execAsync(`git log --oneline -${limit}`, { cwd: this.workspacePath });
      return stdout;
    } catch (error) {
      throw new Error(`Failed to get log: ${error}`);
    }
  }

  async getCurrentBranch(): Promise<string> {
    try {
      const { stdout } = await execAsync('git branch --show-current', { cwd: this.workspacePath });
      return stdout.trim();
    } catch (error) {
      throw new Error(`Failed to get current branch: ${error}`);
    }
  }

  async createBranch(branchName: string): Promise<void> {
    try {
      await execAsync(`git checkout -b ${branchName}`, { cwd: this.workspacePath });
    } catch (error) {
      throw new Error(`Failed to create branch: ${error}`);
    }
  }

  async switchBranch(branchName: string): Promise<void> {
    try {
      await execAsync(`git checkout ${branchName}`, { cwd: this.workspacePath });
    } catch (error) {
      throw new Error(`Failed to switch branch: ${error}`);
    }
  }

  async getRemotes(): Promise<string[]> {
    try {
      const { stdout } = await execAsync('git remote', { cwd: this.workspacePath });
      return stdout.trim().split('\n').filter(remote => remote.trim());
    } catch (error) {
      return [];
    }
  }

  async addRemote(name: string, url: string): Promise<void> {
    try {
      await execAsync(`git remote add ${name} ${url}`, { cwd: this.workspacePath });
    } catch (error) {
      throw new Error(`Failed to add remote: ${error}`);
    }
  }

  async isGitRepository(): Promise<boolean> {
    try {
      await execAsync('git rev-parse --git-dir', { cwd: this.workspacePath });
      return true;
    } catch (error) {
      return false;
    }
  }
}