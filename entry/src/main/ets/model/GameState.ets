/** Game states and swipe directions used by the 2048 board. */
export enum GameStatus {
  PLAYING,
  WIN,
  GAME_OVER
}

export enum SwipeDirection {
  UP,
  DOWN,
  LEFT,
  RIGHT
}

/** A board coordinate used by the Canvas animation layer. */
export interface CellPosition {
  row: number;
  col: number;
}

/** Describes how one source tile travels during a valid move. */
export interface TileMotion {
  fromRow: number;
  fromCol: number;
  toRow: number;
  toCol: number;
  value: number;
}

/** Animation metadata produced together with the final board state. */
export interface MoveAnimation {
  motions: TileMotion[];
  mergedCells: CellPosition[];
  spawnedCell: CellPosition | null;
}
