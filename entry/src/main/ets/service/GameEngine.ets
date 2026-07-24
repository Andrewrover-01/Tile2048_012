import { CellPosition, MoveAnimation, SwipeDirection, TileMotion } from '../model/GameState';

interface LineTile {
  value: number;
  position: CellPosition;
}

/**
 * Framework-independent 2048 rules. Keeping this class free of UI code makes
 * the compression/merge rules deterministic and easy to test.
 */
export class GameEngine {
  size: number = 4;
  private grid: number[][] = [];
  private score: number = 0;
  private previousGrid: number[][] = [];
  private previousScore: number = 0;
  private undoAvailable: boolean = false;
  private lastMoveAnimation: MoveAnimation = {
    motions: [],
    mergedCells: [],
    spawnedCell: null
  };

  constructor() {
    this.init();
  }

  init(): void {
    this.grid = [];
    for (let row = 0; row < this.size; row++) {
      const cells: number[] = [];
      for (let col = 0; col < this.size; col++) {
        cells.push(0);
      }
      this.grid.push(cells);
    }
    this.score = 0;
    this.previousGrid = [];
    this.previousScore = 0;
    this.undoAvailable = false;
    this.clearLastMoveAnimation();
    this.spawnTile();
    this.spawnTile();
  }

  setSize(size: number): void {
    if (size !== 4 && size !== 5 && size !== 6) {
      return;
    }
    this.size = size;
    this.init();
  }

  canUndo(): boolean {
    return this.undoAvailable;
  }

  undo(): boolean {
    if (!this.undoAvailable) {
      return false;
    }
    this.grid = this.copyGrid(this.previousGrid);
    this.score = this.previousScore;
    this.previousGrid = [];
    this.previousScore = 0;
    this.undoAvailable = false;
    this.clearLastMoveAnimation();
    return true;
  }

  getScore(): number {
    return this.score;
  }

  getGrid(): number[][] {
    return this.copyGrid(this.grid);
  }

  private copyGrid(source: number[][]): number[][] {
    const copy: number[][] = [];
    for (let row = 0; row < source.length; row++) {
      copy.push(source[row].slice());
    }
    return copy;
  }

  getLastMoveAnimation(): MoveAnimation {
    const motions: TileMotion[] = [];
    for (let motion of this.lastMoveAnimation.motions) {
      motions.push({
        fromRow: motion.fromRow,
        fromCol: motion.fromCol,
        toRow: motion.toRow,
        toCol: motion.toCol,
        value: motion.value
      });
    }
    const mergedCells: CellPosition[] = [];
    for (let cell of this.lastMoveAnimation.mergedCells) {
      mergedCells.push({ row: cell.row, col: cell.col });
    }
    const spawned = this.lastMoveAnimation.spawnedCell;
    return {
      motions: motions,
      mergedCells: mergedCells,
      spawnedCell: spawned === null ? null : { row: spawned.row, col: spawned.col }
    };
  }

  /** Apply a move and add exactly one random tile only after a valid move. */
  move(direction: SwipeDirection): boolean {
    const gridBeforeMove: number[][] = this.copyGrid(this.grid);
    const scoreBeforeMove: number = this.score;
    let changed = false;
    const motions: TileMotion[] = [];
    const mergedCells: CellPosition[] = [];
    for (let index = 0; index < this.size; index++) {
      const original = this.readLine(index, direction);
      const tiles: LineTile[] = [];
      for (let offset = 0; offset < this.size; offset++) {
        if (original[offset] !== 0) {
          tiles.push({
            value: original[offset],
            position: this.getCellPosition(index, offset, direction)
          });
        }
      }

      const merged: number[] = [];
      for (let offset = 0; offset < this.size; offset++) {
        merged.push(0);
      }
      let sourceIndex = 0;
      let targetOffset = 0;
      while (sourceIndex < tiles.length) {
        const target = this.getCellPosition(index, targetOffset, direction);
        const first = tiles[sourceIndex];
        if (sourceIndex + 1 < tiles.length && first.value === tiles[sourceIndex + 1].value) {
          const second = tiles[sourceIndex + 1];
          const mergedValue = first.value * 2;
          merged[targetOffset] = mergedValue;
          this.score += mergedValue;
          motions.push(this.createMotion(first, target));
          motions.push(this.createMotion(second, target));
          mergedCells.push({ row: target.row, col: target.col });
          sourceIndex += 2;
        } else {
          merged[targetOffset] = first.value;
          motions.push(this.createMotion(first, target));
          sourceIndex++;
        }
        targetOffset++;
      }

      if (!this.sameLine(original, merged)) {
        changed = true;
        this.writeLine(index, direction, merged);
      }
    }
    if (changed) {
      this.previousGrid = gridBeforeMove;
      this.previousScore = scoreBeforeMove;
      this.undoAvailable = true;
      const spawnedCell = this.spawnTileWithPosition();
      this.lastMoveAnimation = {
        motions: motions,
        mergedCells: mergedCells,
        spawnedCell: spawnedCell
      };
    } else {
      this.clearLastMoveAnimation();
    }
    return changed;
  }

  private createMotion(tile: LineTile, target: CellPosition): TileMotion {
    return {
      fromRow: tile.position.row,
      fromCol: tile.position.col,
      toRow: target.row,
      toCol: target.col,
      value: tile.value
    };
  }

  private getCellPosition(index: number, offset: number, direction: SwipeDirection): CellPosition {
    if (direction === SwipeDirection.LEFT) {
      return { row: index, col: offset };
    }
    if (direction === SwipeDirection.RIGHT) {
      return { row: index, col: this.size - 1 - offset };
    }
    if (direction === SwipeDirection.UP) {
      return { row: offset, col: index };
    }
    return { row: this.size - 1 - offset, col: index };
  }

  private clearLastMoveAnimation(): void {
    this.lastMoveAnimation = {
      motions: [],
      mergedCells: [],
      spawnedCell: null
    };
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

  private sameLine(first: number[], second: number[]): boolean {
    for (let index = 0; index < this.size; index++) {
      if (first[index] !== second[index]) {
        return false;
      }
    }
    return true;
  }

  spawnTile(): boolean {
    return this.spawnTileWithPosition() !== null;
  }

  private spawnTileWithPosition(): CellPosition | null {
    const emptyCells: number[][] = [];
    for (let row = 0; row < this.size; row++) {
      for (let col = 0; col < this.size; col++) {
        if (this.grid[row][col] === 0) {
          emptyCells.push([row, col]);
        }
      }
    }
    if (emptyCells.length === 0) {
      return null;
    }
    const location = emptyCells[Math.floor(Math.random() * emptyCells.length)];
    this.grid[location[0]][location[1]] = Math.random() < 0.9 ? 2 : 4;
    return { row: location[0], col: location[1] };
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
