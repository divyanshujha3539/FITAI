# FitAI — Smart Fitness & Nutrition Management Platform

**An AI-powered, cloud-based fitness and nutrition platform built with Next.js, Microsoft Azure, Azure SQL Database, and Microsoft Foundry.**

FitAI is a fitness and nutrition management application designed to help users track their meals, monitor nutritional intake, plan workouts, and make affordable, data-driven fitness decisions. The platform combines artificial intelligence, relational database management, cloud computing, and secure application design in a single system.

The project also demonstrates practical concepts from **RDBMS, Microsoft DP-900, Cloud Security, and System Design**.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Objectives](#objectives)
- [Core Features](#core-features)
- [Technology Stack](#technology-stack)
- [System Architecture](#system-architecture)
- [Database Design](#database-design)
- [Security](#security)
- [Academic Relevance](#academic-relevance)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Environment Configuration](#environment-configuration)
- [Database Setup](#database-setup)
- [Running the Application](#running-the-application)
- [Team Collaboration](#team-collaboration)
- [Testing](#testing)
- [Deployment](#deployment)
- [Future Enhancements](#future-enhancements)

## Project Overview

Many college students struggle to maintain a balanced diet and consistent workout routine while managing limited budgets and busy academic schedules. FitAI aims to address these challenges through an integrated fitness and nutrition platform.

Users can record meals, review nutrition estimates, plan workout schedules, and monitor their progress. AI-assisted meal interpretation helps convert natural-language food descriptions into structured food entries, while deterministic application logic calculates nutritional values from the food database.

The application uses a relational database for persistent storage and cloud services for hosting and AI capabilities.

## Objectives

- Simplify meal and nutrition tracking.
- Provide personalized workout planning and history.
- Help students identify affordable sources of protein and nutrition.
- Use AI to interpret meal descriptions.
- Store and manage structured information using a relational database.
- Apply authentication, authorization, and secure data-access practices.
- Demonstrate cloud architecture and data-management concepts through a practical application.

## Core Features

### 1. AI Meal Analyzer
- Interpret natural-language descriptions of meals.
- Identify candidate foods, portions, and quantities.
- Match candidate foods against the food catalogue.
- Allow users to review and correct proposed entries.
- Calculate nutrition from stored reference data rather than relying on AI-generated arithmetic.

### 2. Nutrition Tracker
- Record breakfast, lunch, dinner, and snacks.
- Track calories, protein, carbohydrates, and fats.
- View daily nutrition totals and historical records.
- Edit or delete recorded meals.

### 3. Adaptive Workout Planner
- Support 3-day, 4-day, 5-day, and 6-day workout splits.
- Generate structured workout schedules.
- Record exercises, sets, repetitions, and weights.
- Review workout history and completion statistics.

### 4. Affordable Nutrition Optimizer
- Compare foods by protein per rupee.
- Suggest budget-conscious food combinations.
- Compare nutritional and estimated cost differences between food alternatives.
- Support practical nutrition planning for college and hostel students.

### 5. Role-Based Access Control
The planned role-based system includes three roles:

- **User:** Manage personal fitness information, meals, workouts, and trainer requests.
- **Trainer:** Review eligible requests and access authorized assigned-customer information.
- **Admin:** Manage trainer and user relationships, review requests, and oversee assignments.

Administrative accounts must be provisioned securely; public registration is restricted to users and trainers.

### 6. Progress Dashboard
- Display nutrition summaries and trends.
- Track workout completion.
- Compare actual records with user-defined goals.
- Present analytics derived from stored application data.

### 7. Fitness Memory Assistant
- Answer supported questions about a user's recorded meals and workouts.
- Use database-backed information to ground responses.
- Clearly identify missing information rather than inventing records.

### 8. Nearby Gym Finder
- Search for nearby gyms using a supported mapping or location-data provider.
- Display available location information and directions.

*Feature availability
