# Flutter_Music Architecture

## Project Vision

Flutter_Music is a modern desktop music player built with Flutter.

### The project focuses on:

* Local music library
* Clean architecture
* Maintainable codebase
* Cross-platform support
* Hi-Res audio support
* Future DSD support

### The project does NOT currently target:

* Music streaming
* User accounts
* Cloud synchronization
* Social features

⸻

## Design Principles

The project should remain simple, modular and maintainable.

### Core principles:

* Separation of concerns
* Composition over inheritance
* Dependency inversion
* Feature-oriented structure
* Testable business logic

⸻

## Architecture

### Application layers:

UI

↓

ViewModel

↓

Repository

↓

Services

↓

Database / Audio Engine / File System

### Rules:

* UI never accesses the database directly.
* UI never interacts with audio libraries directly.
* Business logic belongs to Services or Repositories.
* Models remain immutable whenever possible.

⸻

## Project Structure

```
lib/

app/
Application configuration, routing and themes.

core/
Shared infrastructure.

Contains:

* Audio
* Database
* Services
* Utilities
* Constants

features/
Business features.

Examples:

* Library
* Player
* Playlist
* Search
* Settings

models/
Application models.

widgets/
Reusable UI components.
```
⸻

## Audio Architecture

Playback should always go through AudioEngine.

Example:

UI

↓

PlayerViewModel

↓

PlaybackService

↓

AudioEngine

↓

Platform implementation

The UI must never directly call just_audio or any platform API.

This abstraction allows replacing the playback engine in the future.

⸻

## Data Flow

Music Folder

↓

Library Scanner

↓

Metadata Parser

↓

Database

↓

Repository

↓

ViewModel

↓

UI

⸻

## Core Models

Song

Represents one audio file.

Album

Represents one album.

Artist

Represents one artist.

Playlist

Represents an ordered collection of songs.

PlaybackQueue

Represents the current playing queue.

⸻

## MVP Scope

Version 0.1 includes:

* Import music folder
* Scan local library
* Parse metadata
* Store library in SQLite
* Display song list
* Basic playback
* Previous / Next
* Pause / Resume

Everything else belongs to future milestones.

⸻

## Future Goals

Future versions may include:

* Album artwork
* Lyrics
* Playlist management
* Gapless playback
* ReplayGain
* Hi-Res improvements
* DSD support
* Exclusive output mode
* Plugin architecture

⸻

## Dependency Policy

Prefer packages using:

* MIT
* BSD
* Apache 2.0

Avoid introducing GPL dependencies unless explicitly approved.

Keep third-party dependencies minimal.

⸻

## Documentation

Any architectural change should also update this document.

Architecture documentation is considered part of the source code.