/** Canvas host component. Rendering and game rules remain controlled by GamePage. */
@Component
export struct GameBoard {
  context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  @Prop boardColor: string = '#BBADA0';
  onBoardReady: () => void = () => {};
  onBoardTouch: (event: TouchEvent) => void = (_event: TouchEvent) => {};

  build() {
    Canvas(this.context)
      .width('94%')
      .aspectRatio(1)
      .backgroundColor(this.boardColor)
      .borderRadius(10)
      .onReady(() => this.onBoardReady())
      .onTouch((event: TouchEvent) => this.onBoardTouch(event))
  }
}
