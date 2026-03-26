# Holter

**Holter** is an Eiseron-grade web application built with Elixir and Phoenix. It follows the **Eiseron Engineering Constitution** and is optimized for high-performance, concurrent, and agent-centric development.

## 🚀 Getting Started

### Prerequisites
- Docker & Docker Compose

### Development Environment
To start the development environment:

1. **Setup Dependencies:**
   ```bash
   docker compose run --rm holter mix setup
   ```

2. **Start the Server:**
   ```bash
   docker compose up
   ```

3. **Access the Application:**
   Visit [`localhost:4000`](http://localhost:4000) in your browser.

## 🛠 Engineering Standards

This project adheres to the Eiseron global standards:
- **Architecture:** Vertical development with Phoenix LiveView.
- **Clean Code:** Robert C. Martin (Uncle Bob) principles.
- **Infrastructure:** Fully containerized with Docker Home Persistence.
- **Workflow:** Conventional Commits and atomic branch strategy.

For detailed guidelines, refer to [AGENTS.md](AGENTS.md) and the local [agents/project_specializations.md](agents/project_specializations.md).

## 🧪 Testing

Run the full precommit suite to ensure code quality:
```bash
docker compose run --rm holter mix precommit
```

## 📚 Learn More

- [Eiseron Agents SSoT](https://github.com/eiseron/eiseron-agents)
- [Phoenix Framework Docs](https://hexdocs.pm/phoenix)
- [Elixir Documentation](https://elixir-lang.org/docs.html)
