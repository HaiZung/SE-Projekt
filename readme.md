# Roboter-Projekt (RegioKArgo) – Leitstand Visualisierung

Dieses Projekt ist eine Leitstand-Software zur **visuellen Übersicht und Überwachung von Paketrobotern** im RegioKArgo-Kontext. Auf einer **Karte von Karlsruhe** werden Roboter inkl. **Position** und **Status** angezeigt. Zusätzlich gibt es eine **Simulation**, die einen beispielhaften Tagesablauf mit verschiedenen Roboterzuständen abbildet.  

## Features
- **Kartenübersicht**: Karte mit allen aktiven Robotern als Icons (Positionsdaten).  
- **Roboterdetail**: Übersicht zu Route, Paketliste, Status und 3D-Visualisierung.  
- **Simulation**: Tagesablauf kann **gestartet, pausiert und neu gestartet** werden.  
- **Status-Visualisierung**: Roboterstatus wird visuell hervorgehoben (z.B. Fehlerzustand).  
- **Backend-Anbindung**: Status- und Paketdaten werden über HTTP mit einem externen Backend synchronisiert; DB kann per API zurückgesetzt werden.  

## Tech Stack (High-Level)
- **Frontend**: Godot Engine 4 (GDScript)
- **Datenbank**: MongoDB (serverseitig, über Backend abstrahiert)
- **Backend-Kommunikation**: HTTP Requests (Godot `HTTPRequest`)
- **Animation/3D**: Blender (Modell/Assets)
- **Datenquellen**: OpenStreetMap Tiles + KVV JSON/GeoJSON (Haltestellen/Linien)  

## Projektstruktur (wichtigste Module)
- `DaySimulation.gd` – Simulation Controller (Ablauf, Routenaufbau, Status setzen)
- `MapRoot.gd` – Map & Rendering (Tiles, GeoJSON-Linien, Koordinaten-Umrechnung)
- `robot.gd`, `robot_animations.gd` – Roboter-Visualisierung/Animation (je nach Setup)
- `res://karte/*.json` – KVV Stops/Lines/GeoJSON als Datengrundlage

## Setup & Run (lokal)
1. Repository klonen.
2. Projekt in **Godot 4** öffnen (`project.godot`).
3. Hauptszene starten (Run/Play in Godot).
4. Falls das Backend genutzt wird: sicherstellen, dass das externe Backend läuft und die HTTP-Endpunkte erreichbar sind (Status-Updates, Paket-Requests, DB-Reset).

## Bedienung (Simulation)
- **Start**: startet den Simulationsdurchlauf (Roboter bewegen sich entlang der Routen)
- **Pause**: stoppt Bewegung/Status-Progress
- **Reset**: setzt den Ablauf zurück; optional DB-Reset über Backend-API

## Architektur & Datenmodell
- Architekturdiagramm: `Architekturdiagramm.md`
- Klassendiagramm/Datenmodell: `Klassendiagramm.md`

## Bekannte Probleme / Limitations
- Simulation und Events sind aktuell **fest definiert** (nicht dynamisch generiert).
- Zu schnelles mehrfaches Drücken der Buttons kann die Simulation “aufhängen”.
- Bei der Haltestelle **Durlach** kommt es zu Fehlberechnungen der Strecke.
- 3D-Roboteranimationen sind im Code vorhanden, werden aber nicht in allen Fällen automatisch abgespielt (Workaround: Trigger über Tasten).  

## Contributors
- Flavio Carbone
- Isabell Grimm
- Chantal Held
- Leon Scherer
- Alyssa Schmidt
- Athanasios Tsiagkanas

## Quellen
- Bereitgestellte Materialien aus dem Felix Kurs
- https://docs.godotengine.org/en/stable/classes/class_path2d.html
- https://docs.godotengine.org/en/stable/classes/class_pathfollow2d.html
- https://docs.godotengine.org/en/stable/classes/class_sprite2d.html
- https://www.youtube.com/watch?v=zR1xRnAaWqc
- https://blender.stackexchange.com/questions/195840/how-to-attach-an-animation-to-an-empty
- https://studio.blender.org/blog/our-workflow-with-blender-and-godot/
- https://docs.godotengine.org/en/4.3/tutorials/assets_pipeline/escn_exporter/animation.html
- https://docs.godotengine.org/en/4.3/tutorials/shaders/index.html
- https://medium.com/medialesson/viewports-windows-and-worlds-in-godot-4-c4e268f90cd3
- https://docs.godotengine.org/en/4.4/tutorials/animation/animation_tree.html

