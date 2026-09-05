const http = require('http');
const https = require('https');

const server = http.createServer((req, res) => {
  const url = req.url;

  if (url.startsWith('/v1/apod')) {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Access-Control-Allow-Origin', '*');
    
    https.get('https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY', (nasaRes) => {
      let body = '';
      nasaRes.on('data', chunk => body += chunk);
      nasaRes.on('end', () => {
        res.writeHead(200);
        res.end(body);
      });
    }).on('error', (err) => {
      res.writeHead(500);
      res.end(JSON.stringify({ error: err.message }));
    });
    return;
  }

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.writeHead(200);
  res.end(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>NASA Astronomy Picture of the Day</title>
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;800&display=swap" rel="stylesheet">
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: 'Inter', sans-serif;
          background: #090a0f;
          color: #e2e8f0;
          min-height: 100vh;
          display: flex;
          flex-direction: column;
          align-items: center;
          padding: 2rem 1rem;
        }
        header { text-align: center; margin-bottom: 2rem; }
        h1 {
          font-size: 2.2rem;
          font-weight: 800;
          background: linear-gradient(135deg, #e2e8f0 0%, #38bdf8 100%);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          margin-bottom: 0.5rem;
        }
        .subtitle { color: #94a3b8; font-size: 0.95rem; }
        .card {
          background: #12151e;
          border: 1px solid #1e293b;
          border-radius: 16px;
          max-width: 900px;
          width: 100%;
          overflow: hidden;
          box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5);
        }
        .img-container {
          width: 100%;
          min-height: 350px;
          max-height: 600px;
          background: #050508;
          display: flex;
          flex-direction: column;
          justify-content: center;
          align-items: center;
          position: relative;
        }
        .img-container img {
          width: 100%;
          height: auto;
          max-height: 600px;
          object-fit: contain;
        }
        .video-box {
          padding: 3rem 1.5rem;
          text-align: center;
        }
        .video-btn {
          display: inline-block;
          margin-top: 1rem;
          padding: 0.8rem 1.6rem;
          background: #0284c7;
          color: #fff;
          text-decoration: none;
          font-weight: 600;
          border-radius: 8px;
          transition: background 0.2s;
        }
        .video-btn:hover { background: #0369a1; }
        .content { padding: 2rem; }
        .meta {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 1rem;
        }
        .date {
          background: #1e293b;
          padding: 0.3rem 0.8rem;
          border-radius: 20px;
          font-size: 0.85rem;
          color: #38bdf8;
        }
        .title { font-size: 1.5rem; font-weight: 600; color: #f8fafc; margin-bottom: 1rem; }
        .explanation { line-height: 1.7; color: #cbd5e1; font-size: 0.95rem; }
        .loader { padding: 4rem; text-align: center; color: #38bdf8; font-weight: 600; }
        footer { margin-top: 3rem; color: #64748b; font-size: 0.85rem; }
      </style>
    </head>
    <body>
      <header>
        <h1>🌌 NASA Astronomy Picture of the Day</h1>
        <div class="subtitle">Deployed in GKE via ArgoCD & Jenkins GitOps (Containerized)</div>
      </header>

      <div class="card" id="app">
        <div class="loader">Loading space discovery...</div>
      </div>

      <footer>Powered by NASA APOD Service & Ingress Nginx</footer>

      <script>
        fetch('/v1/apod')
          .then(res => res.json())
          .then(data => {
            let rawUrl = data.url ? data.url.replace('http://', 'https://') : '';
            let mediaHtml = '';

            if (data.media_type === 'video' || rawUrl.includes('youtube') || rawUrl.includes('vimeo') || rawUrl.includes('apod.nasa.gov')) {
              mediaHtml = \`
                <div class="video-box">
                  <p style="font-size: 1.2rem; margin-bottom: 0.5rem;">📹 Today's APOD is a Video / Interactive Media</p>
                  <p style="color: #94a3b8; font-size: 0.9rem;">Direct playback is restricted by NASA security policy.</p>
                  <a href="\${rawUrl}" target="_blank" class="video-btn">▶ Watch Video on NASA APOD</a>
                </div>
              \`;
            } else {
              let safeImgUrl = 'https://images.weserv.nl/?url=' + encodeURIComponent(rawUrl);
              mediaHtml = \`<img src="\${safeImgUrl}" alt="\${data.title}" onError="this.onerror=null; this.src='\${rawUrl}';" />\`;
            }

            document.getElementById('app').innerHTML = \`
              <div class="img-container">
                \${mediaHtml}
              </div>
              <div class="content">
                <div class="meta">
                  <span class="date">📅 \${data.date}</span>
                  \${data.copyright ? \`<span class="date">📷 \${data.copyright}</span>\` : ''}
                </div>
                <h2 class="title">\${data.title}</h2>
                <p class="explanation">\${data.explanation}</p>
              </div>
            \`;
          })
          .catch(err => {
            document.getElementById('app').innerHTML = \`<div class="loader" style="color:#ef4444;">Failed to load NASA APOD data.</div>\`;
          });
      </script>
    </body>
    </html>
  `);
});

server.listen(8080, () => console.log('NASA UI Running on port 8080'));