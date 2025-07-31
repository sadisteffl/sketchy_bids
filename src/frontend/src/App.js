import React, { useState } from "react";
import BiddingGame from "./components/BiddingGame";
import Leaderboard from "./components/Leaderboard";
import './index.css';

const styles = {
    nav: {
        padding: '10px 20px',
        textAlign: 'center',
        backgroundColor: '#333',
    },
    button: {
        margin: '0 15px',
        padding: '10px 20px',
        fontSize: '1em',
        color: 'white',
        backgroundColor: '#007bff',
        border: 'none',
        borderRadius: '5px',
        cursor: 'pointer',
    }
};

function App() {
  const [view, setView] = useState('game'); // 'game' or 'leaderboard'

  return (
    <div>
      <nav style={styles.nav}>
        <button style={styles.button} onClick={() => setView('game')}>Game</button>
        <button style={styles.button} onClick={() => setView('leaderboard')}>Leaderboard</button>
      </nav>
      {view === 'game' ? <BiddingGame /> : <Leaderboard />}
    </div>
  );
}

export default App;