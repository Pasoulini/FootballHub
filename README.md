# Football Hub - Rainmeter Skin

A modern, real-time football scoreboard for [Rainmeter](https://www.rainmeter.net/) that displays live match scores, goal scorers, and event details from major leagues worldwide.

![Football Hub](https://img.shields.io/badge/Rainmeter-Skin-blue) ![Version](https://img.shields.io/badge/Version-1.0-green) ![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- **Live Score Updates** - Automatically refreshes every minute
- **Multi-League Support** - Covers 15+ leagues and competitions
- **Goal Scorers** - Shows who scored and at what minute
- **Penalty Events** - Displays scored penalties and missed/saved penalties with distinct icons
- **Red Cards** - Highlights sendings-off
- **Shootout Support** - Full penalty shootout display with individual results
- **Tomorrow's Fixtures** - Preview upcoming matches
- **Scalable Design** - Adjust size for any monitor resolution (1080p, 2K, 4K)
- **Dark Theme** - Beautiful dark UI that matches any desktop

## Supported Leagues & Teams

### International
| League | Teams Tracked |
|--------|--------------|
| World Cup | All teams |
| Club World Cup | All teams |

### UEFA
| League | Teams Tracked |
|--------|--------------|
| Champions League | All teams |
| Europa League | All teams |
| Conference League | All teams |

### England
| League | Teams Tracked |
|--------|--------------|
| Premier League | Arsenal, Chelsea, Liverpool, Manchester City, Manchester United |
| FA Cup | Arsenal, Chelsea, Liverpool, Manchester City, Manchester United |
| Carabao Cup | Arsenal, Chelsea, Liverpool, Manchester City, Manchester United |

### Spain
| League | Teams Tracked |
|--------|--------------|
| LaLiga | Real Madrid, Barcelona, Atletico Madrid |
| Copa del Rey | Real Madrid, Barcelona, Atletico Madrid |

### Italy
| League | Teams Tracked |
|--------|--------------|
| Serie A | Juventus, Inter, AC Milan, Napoli |
| Coppa Italia | Juventus, Inter, AC Milan, Napoli |

### Germany
| League | Teams Tracked |
|--------|--------------|
| Bundesliga | Bayern Munich, Borussia Dortmund, Bayer Leverkusen |
| DFB Pokal | Bayern Munich, Borussia Dortmund, Bayer Leverkusen |

### France
| League | Teams Tracked |
|--------|--------------|
| Ligue 1 | PSG (Paris Saint-Germain) |
| Coupe de France | PSG (Paris Saint-Germain) |

### Other
| League | Teams Tracked |
|--------|--------------|
| Saudi Pro League | Al Nassr |
| MLS | Inter Miami |

> **Note:** For international tournaments (World Cup, Club World Cup) and European competitions (Champions League, Europa League), all teams are shown. For domestic leagues, only the tracked teams above are displayed.

## Installation

### Prerequisites
- [Rainmeter](https://www.rainmeter.net/) 4.5.18 or later
- Windows 10/11

### Steps

1. **Download** the latest release from the [Releases](https://github.com/Pasoulini/FootballHub/releases) page
2. **Extract** the `FootballHub` folder to your Rainmeter skins directory:
   ```
   C:\Users\<YourUsername>\Documents\Rainmeter\Skins\
   ```
3. **Refresh Rainmeter** - Right-click the Rainmeter tray icon and select "Refresh all"
4. **Load the skin** - In Rainmeter, navigate to `Skins > FootballHub` and double-click `FootballHub.ini`

### First Run
On first load, the skin will fetch match data from ESPN's API. This may take a few seconds. The data auto-refreshes every minute.

## Configuration

### Scaling (Resize)

The skin supports scaling for different monitor resolutions. Edit `FootballHub.ini` and change the `Scale` variable:

```ini
[Variables]
Scale=1.0    ; Default (2K/1440p)
```

| Scale | Recommended For |
|-------|----------------|
| `0.75` | 1080p / Full HD |
| `1.0` | 1440p / 2K (default) |
| `1.25` | 2160p / 4K |

After changing, refresh the skin in Rainmeter.

### Data Settings

Edit `@Resources/Generate-FootballHub.ps1` to customize:

```powershell
$ShowMissedPenalties = $true          # Show missed/saved penalties
$PenaltyMinuteDisplay = "Hide"        # How to show penalty minutes: AsIs, Hide, ShowPen
$FinishedSortOrder = "NewestFirst"     # Finished matches order: NewestFirst, OldestFirst
```

### Team Filtering

To track specific teams in domestic leagues, edit the `$Leagues` array in `Generate-FootballHub.ps1`:

```powershell
@{ Slug = "eng.1"; Name = "Premier League"; Priority = 10; Teams = @("Arsenal", "Chelsea", "Liverpool") }
```

- Leave `Teams = @()` empty to show all matches in that league
- Add team names to filter and only show matches involving those teams

### Manual Refresh

Click the **Refresh** button on the skin, or run:
```powershell
 powershell -ExecutionPolicy Bypass -File "@Resources\Generate-FootballHub.ps1" -RefreshRainmeter
```

## File Structure

```
FootballHub/
├── FootballHub.ini              # Main skin layout
├── @Resources/
│   ├── Data.inc                 # Generated match data (auto-updated)
│   ├── Generate-FootballHub.ps1 # Data fetcher script
│   ├── Refresh-FootballHub.vbs  # VBScript wrapper for auto-refresh
│   ├── Refresh-FootballHub.cmd  # CMD wrapper
│   ├── Cache/                   # Team logos and cached data
│   └── Icons/                   # Event icons (goal, penalty, etc.)
│       ├── goal.png
│       ├── penalty.png
│       ├── missed-penalty.png
│       └── red-card.png
└── .gitignore
```

## Event Icons

| Icon | Meaning |
|------|---------|
| ![Goal](https://via.placeholder.com/16/4CAF50/ffffff?text=⚽) | Goal scored |
| ![Penalty](https://via.placeholder.com/16/2196F3/ffffff?text=P) | Penalty scored |
| ![Missed Penalty](https://via.placeholder.com/16/FFC107/000000?text=MP) | Penalty missed or saved |
| ![Red Card](https://via.placeholder.com/16/F44336/ffffff?text=RC) | Red card |

## Data Source

Match data is sourced from the [ESPN API](https://site.api.espn.com/). The skin fetches:
- Live and recent match scores
- Goal scorers and minutes
- Penalty events (scored and missed)
- Red cards
- Shootout results

## Customization

### Colors
Edit the color variables in `FootballHub.ini`:
```ini
[Variables]
Text=245,247,250,255      ; Main text color
Muted=170,180,195,255     ; Muted/secondary text
Accent=86,182,255,255     ; Accent color (league names)
Green=60,220,140,255      ; Badge/text color
Card=18,24,38,225         ; Card background
Panel=10,14,24,210        ; Panel background
```

### Fonts
The skin uses Segoe UI (default Windows font). To change:
```ini
FontMain=Segoe UI
FontBold=Segoe UI Semibold
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No data showing | Check internet connection; run manual refresh |
| Skin too small/large | Adjust `Scale` variable in `FootballHub.ini` |
| Missing matches | Check team names in `$Leagues` configuration |
| Auto-refresh not working | Ensure `Refresh-FootballHub.vbs` is not blocked by antivirus |

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Parsa Rasouli**

## Acknowledgments

- [Rainmeter](https://www.rainmeter.net/) - Desktop customization platform
- [ESPN API](https://developer.espn.com/) - Match data source
- Font Awesome - Icons inspiration
