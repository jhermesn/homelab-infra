import express, { json } from 'express';
import { createConnection, createPool } from 'mysql2/promise';
import { createClient } from 'redis';

const app = express();
app.use(json());

const PORT = process.env.PORT;
const MYSQL_CONFIG = {
  host: process.env.MYSQL_HOST,
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
};

let dbParams;
let redisClient;

async function init() {
  redisClient = createClient({
    url: `redis://${process.env.REDIS_HOST}:${process.env.REDIS_PORT}`
  });

  redisClient.on('error', err => console.error('Redis Client Error', err));

  await redisClient.connect();
  console.log('Connected to Redis!');

  const connection = await createConnection(MYSQL_CONFIG);
  await connection.execute(`
    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      email VARCHAR(255) NOT NULL
    )
  `);
  console.log('Connected to MySQL!');
  
  await connection.end(); 
  
  dbParams = createPool(MYSQL_CONFIG);

  app.listen(PORT, () => {
    console.log(`🚀 Demo CRUD running on port ${PORT}`);
  });
}

app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'demo-crud' });
});

app.post('/users', async (req, res) => {
  const { name, email } = req.body;

  try {
    const [result] = await dbParams.execute(
      'INSERT INTO users (name, email) VALUES (?, ?)',
      [name, email]
    );
    
    await redisClient.del('users_list');
    console.log(`User created: ${name} (ID: ${result.insertId})`);
    
    res.status(201).json({ id: result.insertId, name, email });
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/users', async (req, res) => {
  try {
    const cachedUsers = await redisClient.get('users_list');

    if (cachedUsers) {
      console.log('Cache Hit! Returning from Redis.');
      return res.json(JSON.parse(cachedUsers));
    }

    console.log('Cache Miss. Querying MySQL.');
    const [rows] = await dbParams.query('SELECT * FROM users');
    
    await redisClient.set('users_list', JSON.stringify(rows), { EX: 60 });
    
    res.json(rows);
  } catch (error) {
    console.error('Error listing users:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/error', (req, res) => {
  throw new Error("Forced error!");
});

init().catch(err => {
  console.error("Fatal initialization failure:", err);
  process.exit(1);
});
