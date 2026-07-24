import { SwipeDirection } from '../model/GameState';

/**
 * Framework-independent 2048 rules. Keeping this class free of UI code makes
 * the compression/merge rules deterministic and easy to test.
 */
export class GameEngine {
  readonly size: number = 4;
  private grid: number[][] = [];
  private score: number = 0;

  constructor() {
    this.init();
  }

  init(): void {
    this.grid = [];
    for (let row = 0; row < this.size; row++) {
      this.grid.push([0, 0, 0, 0]);
    }
    this.score = 0;
    this.spawnTile();
    this.spawnTile();
  }

  getScore(): number {
    return this.score;
  }

  getGrid(): number[][] {
    const copy: number[][] = [];
    for (let row = 0; row < this.size; row++) {
      copy.push(this.grid[row].slice());
    }
    return copy;
  }

  /** Apply a move and add exactly one random tile only after a valid move. */
  move(direction: SwipeDirection): boolean {
    let changed = false;
    for (let index = 0; index < this.size; index++) {
      const original = this.readLine(index, direction);
      const merged = this.mergeLine(original);
      if (!this.sameLine(original, merged)) {
        changed = true;
        this.writeLine(index, direction, merged);
      }
    }
    if (changed) {
      this.spawnTile();
    }
    return changed;
  }

  private readLine(index: number, direction: SwipeDirection): number[] {
    const line: number[] = [];
    for (let offset = 0; offset < this.size; offset++) {
      if (direction === SwipeDirection.LEFT) {
        line.push(this.grid[index][offset]);
      } else if (direction === SwipeDirection.RIGHT) {
        line.push(this.grid[index][this.size - 1 - offset]);
      } else if (direction === SwipeDirection.UP) {
        line.push(this.grid[offset][index]);
      } else {
        line.push(this.grid[this.size - 1 - offset][index]);
      }
    }
    return line;
  }

  private writeLine(index: number, direction: SwipeDirection, line: number[]): void {
    for (let offset = 0; offset < this.size; offset++) {
      if (direction === SwipeDirection.LEFT) {
        this.grid[index][offset] = line[offset];
      } else if (direction === SwipeDirection.RIGHT) {
        this.grid[index][this.size - 1 - offset] = line[offset];
      } else if (direction === SwipeDirection.UP) {
        this.grid[offset][index] = line[offset];
      } else {
        this.grid[this.size - 1 - offset][index] = line[offset];
      }
    }
  }

  /** Compress -> merge once per adjacent pair -> pad with empty cells. */
  private mergeLine(line: number[]): number[] {
    const compact: number[] = [];
    for (let value of line) {
      if (value !== 0) {
        compact.push(value);
      }
    }
    const result: number[] = [];
    let index = 0;
    while (index < compact.length) {
      if (index + 1 < compact.length && compact[index] === compact[index + 1]) {
        const value = compact[index] * 2;
        result.push(value);
        this.score += value;
        index += 2;
      } else {
        result.push(compact[index]);
        index++;
      }
    }
    while (result.length < this.size) {
      result.push(0);
    }
    return result;
  }

  private sameLine(first: number[], second: number[]): boolean {
    for (let index = 0; index < this.size; index++) {
      if (first[index] !== second[index]) {
        return false;
      }
    }
    return true;
  }

  spawnTile(): boolean {
    const emptyCells: number[][] = [];
    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size; col++) {
        if (this.grid[row][col] === 0) {
          emptyCells.push([row, col]);
        }
      }
    }
    if (emptyCells.length === 0) {
      return false;
    }
    const location = emptyCells[Math.floor(Math.random() * emptyCells.length)];
    this.grid[location[0]][location[1]] = Math.random() < 0.9 ? 2 : 4;
    return true;
  }

  hasWon(): boolean {
    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size; col++) {
        if (this.grid[row][col] >= 2048) {
          return true;
        }
      }
    }
    return false;
  }

  isGameOver(): boolean {
    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size; col++) {
        const value = this.grid[row][col];
        if (value === 0) {
          return false;
        }
        if (row + 1 < this.size && value === this.grid[row + 1][col]) {
          return false;
        }
        if (col + 1 < this.size && value === this.grid[row][col + 1]) {
          return false;
        }
      }
    }
    return true;
  }
}
