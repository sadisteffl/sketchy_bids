import React, { useState, useEffect } from "react";
import axios from "axios";

const styles = {
    container: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        padding: '20px',
        fontFamily: "'Helvetica Neue', Arial, sans-serif",
    },
    header: {
        fontSize: '2.5em',
        marginBottom: '20px',
    },
    table: {
        width: '80%',
        maxWidth: '600px',
        borderCollapse: 'collapse',
        boxShadow: '0 4px 8px rgba(0,0,0,0.1)',
    },
    th: {
        backgroundColor: '#007bff',
        color: 'white',
        padding: '12px',
        border: '1px solid #ddd',
    },
    td: {
        padding: '10px',
        textAlign: 'center',
        border: '1px solid #ddd',
    },
    tr: {
        '&:nth-child(even)': {
            backgroundColor: '#f2f2f2',
        }
    }
};

const Leaderboard = () => {
    const [leaderboard, setLeaderboard] = useState([]);

    useEffect(() => {
        const fetchLeaderboard = async () => {
            try {
                // This endpoint already exists on your backend
                const response = await axios.get(`${process.env.REACT_APP_API_URL}/leaderboard`);
                setLeaderboard(response.data);
            } catch (error) {
                console.error("Error fetching leaderboard:", error);
            }
        };
        fetchLeaderboard();
    }, []);

    return (
        <div style={styles.container}>
            <h1 style={styles.header}>Leaderboard</h1>
            <table style={styles.table}>
                <thead>
                    <tr>
                        <th style={styles.th}>Rank</th>
                        <th style={styles.th}>Username</th>
                        <th style={styles.th}>Score</th>
                    </tr>
                </thead>
                <tbody>
                    {leaderboard.map((user, index) => (
                        <tr key={user.username} style={styles.tr}>
                            <td style={styles.td}>{index + 1}</td>
                            <td style={styles.td}>{user.username}</td>
                            <td style={styles.td}>{user.score}</td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
};

export default Leaderboard;