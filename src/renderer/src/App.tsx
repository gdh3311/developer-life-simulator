const APPS = ['DevIDE', 'Terminal', 'TeamChat', 'TaskBoard', 'Wiki', 'AICode']

export default function App() {
  return (
    <div className="desktop">
      <header className="topbar">
        <span>WORKSTATION OS</span>
        <span>MON 09:00</span>
      </header>
      <main className="workspace">
        <div className="window">
          <div className="window-title">Welcome · NEXORA</div>
          <div className="window-body">
            <p>NEXORA에 오신 것을 환영합니다. 첫 출근 준비 중...</p>
          </div>
        </div>
      </main>
      <nav className="dock">
        {APPS.map((name) => (
          <button key={name}>{name}</button>
        ))}
      </nav>
    </div>
  )
}
