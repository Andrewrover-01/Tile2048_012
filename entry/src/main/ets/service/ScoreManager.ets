import dataPreferences from '@ohos.data.preferences';

/** Stores only the best score, leaving a backgrounded game in memory. */
class ScoreManager {
  private preferences: dataPreferences.Preferences | null = null;
  private readonly preferenceName: string = 'tile2048_preferences';
  private readonly bestScoreKey: string = 'best_score';

  async configure(context: Context): Promise<void> {
    this.preferences = await dataPreferences.getPreferences(context, this.preferenceName);
  }

  async getBestScore(): Promise<number> {
    if (this.preferences === null) {
      return 0;
    }
    return await this.preferences.get(this.bestScoreKey, 0) as number;
  }

  async saveBestScore(score: number): Promise<void> {
    if (this.preferences === null) {
      return;
    }
    const current = await this.getBestScore();
    if (score > current) {
      await this.preferences.put(this.bestScoreKey, score);
      await this.preferences.flush();
    }
  }
}

export const scoreManager: ScoreManager = new ScoreManager();
