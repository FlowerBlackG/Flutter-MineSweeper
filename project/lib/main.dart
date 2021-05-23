import 'dart:html';
import 'dart:math';

import 'package:flutter/material.dart';

/// How much background images are available.
const BACKGROUND_IMG_COUNT = 6;

/// Background image root.
const BACKGROUND_IMG_ROOT = 'assets/background';

/// Parameters of gameboard's size.
const GAMEBOARD_WIDTH = 840.0;
const GAMEBOARD_RATIO = 4.0 / 3;
const GAMEBOARD_HEIGHT = GAMEBOARD_WIDTH * GAMEBOARD_RATIO;

/// Parameters of mines.
const BLOCK_COLUMNS = 12;
const BLOCK_ROWS = BLOCK_COLUMNS ~/ 4 * 3;
const MINE_COUNT = 10;
const BLOCK_COUNT = BLOCK_COLUMNS * BLOCK_ROWS;

class BlockInfoPack {
  bool isMine;
  bool isCovered;
  bool isFlag;
  int minesAround;

  GlobalKey key;

  BlockInfoPack() {
    isMine = false;
    isCovered = true;
    isFlag = false;
    minesAround = 0;
  }

  MaterialColor getColor() {
    if (isCovered) {
      if (!isFlag) {
        return Colors.lightGreen;
      }
      return Colors.teal;
    }

    if (isMine) {
      return Colors.red;
    }

    return Colors.green;
  }

  double getOpacity() {
    if (isCovered || isMine) {
      return 0.92;
    }

    if (minesAround > 0) {
      return 0.84;
    }

    return 0.0;
  }

  String getShowText() {
    if (isCovered) {
      if (isFlag) {
        return '️!';
      }
      return '';
    }

    if (isMine) {
      return '*';
    }

    return minesAround.toString();
  }
}

class Coord {
  int x, y;

  Coord(int x, int y) {
    this.x = x;
    this.y = y;
  }
}

/// 将数组下标转换为坐标。
Coord idx2coord(int idx) {
  return Coord(
      idx % BLOCK_COLUMNS,
      idx ~/ BLOCK_COLUMNS
  );
}

/// 将坐标转换为数组下标。
int coord2idx(Coord c) {
  return c.y * BLOCK_COLUMNS + c.x;
}

/// 存储每个格子的信息。
var _blockInfoList = List.generate(BLOCK_COUNT, (index) => BlockInfoPack());

/// 生成雷。
void _generateMine(Coord begPos) {
  _blockInfoList.forEach((element) {
    element.isMine = false;
    element.isCovered = true;
    element.isFlag = false;
    element.minesAround = 0;
  });

  var rand = Random(DateTime.now().millisecondsSinceEpoch);
  var avaiIdx = List.generate(BLOCK_COUNT, (index) => index);
  
  List<int> protectedIndex = [];
  
  for (int i = begPos.x - 1; i <= begPos.x + 1; i++) {
    for (int j = begPos.y - 1; j <= begPos.y + 1; j++) {
      if (i < 0 || j < 0 || i >= BLOCK_COLUMNS || j >= BLOCK_ROWS) {
        continue;
      }
      protectedIndex.add(coord2idx(Coord(i, j)));
    }
  }

  // 倒序排序
  protectedIndex.sort((a, b) {return b - a;});

  protectedIndex.forEach((element) {
    avaiIdx.removeAt(element);
  });
  
  for (int i = 0; i < MINE_COUNT; i++) {
    int randIdx = rand.nextInt(avaiIdx.length);
    _blockInfoList[avaiIdx[randIdx]].isMine = true;
    avaiIdx.removeAt(randIdx);
  }

  for (int i = 0; i < BLOCK_COUNT; i++) {
    Coord coord = idx2coord(i);
    _blockInfoList[i].minesAround = countMineAround(coord);
  }
}

int countMineAround(Coord coord) {
  int res = 0;
  for (int i = coord.x - 1; i <= coord.x + 1; i++) {
    for (int j = coord.y - 1; j <= coord.y + 1; j++) {
      if (i < 0 || j < 0 || i >= BLOCK_COLUMNS || j >= BLOCK_ROWS) {
        continue;
      }

      if (_blockInfoList[coord2idx(Coord(i, j))].isMine) {
        res++;
      }

    }
  }
  return res;
}
int countFlagAround(Coord coord) {
  int res = 0;
  for (int i = coord.x - 1; i <= coord.x + 1; i++) {
    for (int j = coord.y - 1; j <= coord.y + 1; j++) {
      if (i < 0 || j < 0 || i >= BLOCK_COLUMNS || j >= BLOCK_ROWS) {
        continue;
      }

      var thisBlock = _blockInfoList[coord2idx(Coord(i, j))];

      if (thisBlock.isFlag && thisBlock.isCovered) {
        res++;
      }

    }
  }
  return res;
}

class BlockUncoverResPack {
  bool update;
  bool alive;
  BlockUncoverResPack(bool update, bool alive) {
    this.update = update;
    this.alive = alive;
  }
}
BlockUncoverResPack _blockUncover(int pos) {
  BlockInfoPack thisBlock = _blockInfoList[pos];

  // 如果已经打开，或者是旗子，则不执行操作。
  if (!thisBlock.isCovered || thisBlock.isFlag) {
    return BlockUncoverResPack(false, true);
  }

  BlockUncoverResPack ret = BlockUncoverResPack(false, true);

  // 打开这个格子。
  thisBlock.isCovered = false;
  ret.update = true;

  // 如果是雷，直接将失败信息传回。
  if (thisBlock.isMine) {
    ret.alive = false;
    return ret;
  }

  Coord thisCoord = idx2coord(pos);

  if (countMineAround(thisCoord) > 0) {
    return ret;
  }

  for (int i = thisCoord.x - 1; i <= thisCoord.x + 1; i++) {
    for (int j = thisCoord.y - 1; j <= thisCoord.y + 1; j++) {
      // 忽略非法区域。
      if (i < 0 || j < 0 || i >= BLOCK_COLUMNS || j >= BLOCK_ROWS) {
        continue;
      }

      int nextIndex = coord2idx(Coord(i, j));
      BlockUncoverResPack dfsRes = _blockUncover(nextIndex);

      ret.alive &= dfsRes.alive;
    }
  }

  return ret;

}

bool _isGameSuccess() {
  int covered = BLOCK_COLUMNS * BLOCK_ROWS;

  _blockInfoList.forEach((element) {
    if (!element.isCovered) {
      covered--;
    }
  });

  return covered == MINE_COUNT;
}

/// Programs' entry point.
void main() {
  window.document.onContextMenu.listen((event) => event.preventDefault());
  runApp(GameAppActivity());
}

/// Main Activity.
class GameAppActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '扫雷',
      home: GameApp(),
    );
  }
}

class GameApp extends StatefulWidget {
  @override
  _GameAppState createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  var _random = Random(DateTime.now().millisecondsSinceEpoch);

  var _lastImgIndex = 0;

  var _imgTarget =
      '$BACKGROUND_IMG_ROOT/bg0.webp';

  bool _mineGenerated = false;

  void _restartGame() {
    _blockInfoList.forEach((element) {
      element.isMine = false;
      element.isCovered = true;
      element.isFlag = false;
      element.minesAround = 0;
    });

    int newImgIndex = _random.nextInt(BACKGROUND_IMG_COUNT - 1);
    if (newImgIndex == _lastImgIndex) {
      newImgIndex = BACKGROUND_IMG_COUNT - 1;
    }
    _lastImgIndex = newImgIndex;

    _imgTarget =
      '$BACKGROUND_IMG_ROOT/bg$newImgIndex.webp';

    _mineGenerated = false;

    _showHelpDialog();

    setState(() {});
  }

  _showFailureDialog() {

    Widget okButton = TextButton(
        onPressed: () {
          Navigator.pop(context);
          _restartGame();
        },
        child: Text('重试')
    );

    AlertDialog alert = AlertDialog(
      title: Text('失败'),
      content: Text('踩到雷了哦'),
      actions: [
        okButton
      ],
    );

    showDialog(context: context, builder: (BuildContext context) => alert);
  }

  _showSuccessDialog() {
    Widget okButton = TextButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: Text('好耶')
    );

    AlertDialog alert = AlertDialog(
      title: Text('成功啦'),
      content: Text('点击右下角那个按钮试试～'),
      actions: [
        okButton
      ],
    );

    showDialog(context: context, builder: (BuildContext context) => alert);
  }

  _showHelpDialog() {
    Widget okButton = TextButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: Text('好的')
    );

    AlertDialog alert = AlertDialog(
      title: Text('经典的扫雷游戏'),
      content: Text(
          '单击：打开一个未知格子'
          '\n长按：插上或拔出标记旗'
          '\n双击：快速打开周围格子'
      ),
      actions: [
        okButton
      ],
    );

    showDialog(context: context, builder: (BuildContext context) => alert);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Stack(
          children: <Widget>[
            Container(
              width: GAMEBOARD_WIDTH,
              height: GAMEBOARD_HEIGHT,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_imgTarget)
                )
              ),
            ),
            Container(
              width: GAMEBOARD_WIDTH,
              height: GAMEBOARD_HEIGHT,
              child: Center(
                child: GridView.count(
                  crossAxisCount: BLOCK_COLUMNS,
                  shrinkWrap: true,
                  children: List.generate(BLOCK_COUNT, (pos) {
                  return StatefulBuilder(
                    builder: (BuildContext context, StateSetter partlyRefresh) {
                      return Opacity(
                        opacity: _blockInfoList[pos].getOpacity(),
                        child: Material(
                          child: Ink(
                            color: _blockInfoList[pos].getColor(),
                            child: InkWell(
                              onTap: () {
                                if (!_mineGenerated) {
                                  _generateMine(idx2coord(pos));
                                  _mineGenerated = true;
                                }

                                BlockUncoverResPack dfsRes = _blockUncover(pos);

                                if (dfsRes.update) {
                                  if (!dfsRes.alive) {
                                    _showFailureDialog();
                                  } else if (_isGameSuccess()) {
                                    _blockInfoList.forEach((element) {
                                      element.isCovered = false;
                                      element.isMine = false;
                                      element.isFlag = false;
                                      element.minesAround = 0;
                                    });
                                    _showSuccessDialog();
                                  }

                                  setState(() {});
                                }
                              },

                              onLongPress: () {
                                BlockInfoPack infoObj = _blockInfoList[pos];
                                infoObj.isFlag = !infoObj.isFlag;

                                partlyRefresh(() {});
                              },

                              onDoubleTap: () {
                                if (countMineAround(idx2coord(pos))
                                    == countFlagAround(idx2coord(pos))) {

                                  Coord coord = idx2coord(pos);

                                  bool alive = true;

                                  for (int i = coord.x - 1; i <= coord.x + 1; i++) {
                                    for (int j = coord.y - 1; j <= coord.y + 1; j++) {
                                      if (i < 0 || j < 0 || i >= BLOCK_COLUMNS || j >= BLOCK_ROWS) {
                                        continue;
                                      }

                                      alive &= _blockUncover(coord2idx(Coord(i, j))).alive;

                                    }
                                  }

                                  if (!alive) {
                                    _showFailureDialog();
                                  } else {
                                    if (_isGameSuccess()) {
                                      _blockInfoList.forEach((element) {
                                        element.isCovered = false;
                                        element.isMine = false;
                                        element.isFlag = false;
                                        element.minesAround = 0;
                                      });
                                      _showSuccessDialog();
                                    }
                                  }

                                  setState(() {});
                                }

                              },

                              child: Container(
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.white,
                                        width: 0.15
                                    )
                                ),
                                child: Center(
                                  child: Text(
                                    _blockInfoList[pos].getShowText(),
                                    //_blockInfoList[pos].getShowText(),
                                    style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
                )
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _restartGame,
        child: Icon(Icons.refresh),
      ),
    );
  }
}
