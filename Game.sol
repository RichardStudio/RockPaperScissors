// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

contract RockPaperScissors{

    /**
    * Possible moves
    */
    enum Move{
        Rock,
        Paper,
        Scissors
    }

    /**
    * Game states
    */
    enum State{
        Stopped,
        WaitingForPlayer,
        WaitingForReveal,
        WaitingForEnd
    }

    State public GameState;
    uint256 LastAction;

    function ChangeGameState (State newGameState) private{
        GameState = newGameState;
        LastAction = block.timestamp;
    }

    uint256 public Bet;
    address public PlayerOne;
    address public PlayerTwo;
    Move public PlayerOneMove;
    Move public PlayerTwoMove;
    bytes32 public HiddenMove;
    mapping(address => uint256) public balance;

    event PlayerMove(address player, Move move);

    event Winner(address winner, uint256 amount);

    event Tie(address playerOne, address playerTwo, uint256 amount);

    event TimeOut(address winner, uint256 amount);

    constructor(uint256 _timeout, uint256 _bet) {
        Timeout = _timeout;
        Bet = _bet;
    }

    modifier StoppedGameState {
        require(GameState == State.Stopped, "Game in progress");
        _;
    }
    modifier WaitingForPlayerState {
        require(GameState == State.WaitingForPlayer, "Game is not waiting for 2nd player");
        _;
    }
    modifier WaitingForReveal {
        require(GameState == State.WaitingForReveal, "Game is not waiting for reveal");
        _;
    }
    modifier NotStopped {
        require(GameState != State.Stopped, "Game does not exist");
        _;
    }

    function CheckWinner() private{
        if(PlayerOneMove == PlayerTwoMove){
            balance[PlayerOne] = Bet;
            balance[PlayerTwo] = Bet;
        } else if(PlayerOneMove == Move.Rock){
            if(PlayerTwoMove == Move.Paper){
                balance[PlayerTwo] = 2 * Bet;
                balance[PlayerOne] = 0;
            }
            if(PlayerTwoMove == Move.Scissors){
                balance[PlayerOne] = 2 * Bet;
                balance[PlayerTwo] = 0;
            }
        } else if (PlayerOneMove == Move.Paper){
            if (PlayerTwoMove == Move.Scissors){
                balance[PlayerTwo] = 2 * Bet;
                balance[PlayerOne] = 0;
            }
            if (PlayerTwoMove == Move.Rock){
                balance[PlayerOne] = 2 * Bet;
                balance[PlayerTwo] = 0;
            }
        } else if (PlayerOneMove == Move.Scissors){
            if (PlayerTwoMove == Move.Rock){
                balance[PlayerTwo] = 2 * Bet;
                balance[PlayerOne] = 0;
            }
            if (PlayerTwoMove == Move.Paper){
                balance[PlayerOne] = 2 * Bet;
                balance[PlayerTwo] = 0;
            }
        }

        if (balance[PlayerOne] == balance[PlayerTwo]){
            emit Tie(PlayerOne, PlayerTwo, Bet);
        } else if (balance[PlayerOne] > 0){
            emit Winner(PlayerOne, balance[PlayerOne]);
        } else if (balance[PlayerTwo] > 0){
            emit Winner(PlayerTwo, balance[PlayerTwo]);
        }
    }

    function Withdraw(address target) public {
        require(balance[msg.sender] > 0, "Cannot withdraw 0!");

        uint256 playerBalance = balance[msg.sender];
        balance[msg.sender] = 0;
        (bool success,) = target.call{value: playerBalance}("");

        if (!success) {
            balance[msg.sender] = playerBalance;
        }
    }

    uint256 Timeout;

    function TimeoutAt() public view returns (uint256) {
        return LastAction + Timeout;
    }

    function IsTimedOut() private view returns (bool) {
        return block.timestamp >= TimeoutAt();
    }
    
    function Start(bytes32 hiddenMove) public payable StoppedGameState{
        require(msg.value == Bet, "Bet does not match with preset");
        PlayerOne = msg.sender;
        HiddenMove = hiddenMove;

        ChangeGameState(State.WaitingForPlayer);
    }

    function Join(Move move) public payable WaitingForPlayerState{
        require(msg.value == Bet, "Bet does not match with preset");
        PlayerTwo = msg.sender;
        PlayerTwoMove = move;

        emit PlayerMove(PlayerTwo, PlayerTwoMove);
        ChangeGameState(State.WaitingForReveal);
    }

    function Reveal(Move move, uint256 nonce) public WaitingForReveal{
        bytes32 hashed = keccak256(abi.encode(move, nonce));
        assert(hashed == HiddenMove);
        PlayerOneMove = move;

        emit PlayerMove(PlayerOne, PlayerOneMove);
        ChangeGameState(State.WaitingForEnd);
        EndGame();
    }

    function EndGame() public NotStopped{
        if (GameState == State.WaitingForPlayer){
            require(IsTimedOut(), "It is not timeout yet");
            balance[PlayerOne] = Bet;
            emit TimeOut(PlayerOne, Bet);
        } else
        if (GameState == State.WaitingForReveal){
            require(IsTimedOut(), "It is not timeout yet");
            balance[PlayerTwo] = 2 * Bet;
            emit TimeOut(PlayerTwo, balance[PlayerTwo]);
        } else {
            CheckWinner();
        }
        ChangeGameState(State.Stopped);
        delete PlayerOne;
        delete PlayerTwo;
        delete PlayerOneMove;
        delete PlayerTwoMove;
        delete HiddenMove;
    }
}