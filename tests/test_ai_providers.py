import unittest

from helpers import ROOT, node_eval

PROVIDERS = ROOT / "services" / "AiProviders.js"

TAGS = {
    "models": [
        {"name": "qwen3:8b", "details": {"parameter_size": "8.2B", "quantization_level": "Q4_K_M"}, "size": 5225388164,
         "capabilities": ["completion", "tools", "thinking"]},
        {"name": "nomic-embed-text:latest", "details": {"parameter_size": "137M", "family": "nomic-bert"}, "size": 274302450,
         "capabilities": ["embedding"]},
        {"name": "all-minilm:latest", "details": {"family": "bert", "families": ["bert"]}, "size": 45960996},
        {"name": "llama3.2:latest", "details": {"parameter_size": "3.2B", "quantization_level": "Q4_K_M"}, "size": 2019393189},
    ]
}


class AiProvidersTest(unittest.TestCase):
    def test_ollama_base_drops_the_v1_suffix(self):
        self.assertEqual(node_eval(PROVIDERS, "['http://localhost:11434/v1', 'http://box:11434/v1/', 'http://box:11434'].map(ollamaBase)"),
                         ["http://localhost:11434", "http://box:11434", "http://box:11434"])

    def test_ollama_models_skip_embedding_models_and_show_size(self):
        models = node_eval(PROVIDERS, f"ollamaModels({__import__('json').dumps(TAGS)})")
        self.assertEqual([m["id"] for m in models], ["llama3.2:latest", "qwen3:8b"])
        self.assertEqual(models[1]["name"], "qwen3:8b")
        self.assertEqual(models[1]["details"], "8.2B · Q4_K_M · 5.2 GB")

    def test_ollama_models_of_an_empty_list(self):
        self.assertEqual(node_eval(PROVIDERS, "[ollamaModels({}), ollamaModels({models: []})]"), [[], []])

    def test_ollama_pull_progress(self):
        self.assertEqual(node_eval(PROVIDERS, "pullProgress({status: 'pulling abc', total: 200, completed: 50})"),
                         {"status": "pulling abc", "fraction": 0.25, "done": False, "error": ""})
        self.assertEqual(node_eval(PROVIDERS, "pullProgress({status: 'success'})")["done"], True)
        self.assertEqual(node_eval(PROVIDERS, "pullProgress({error: 'pull model manifest: file does not exist'})")["error"],
                         "pull model manifest: file does not exist")

    def test_model_names_are_checked_before_a_pull(self):
        self.assertEqual(node_eval(PROVIDERS, "['llama3.2', 'qwen3:8b', 'hf.co/user/repo:Q4_K_M', 'a b', '', '$(rm)', '-v'].map(validModelName)"),
                         [True, True, True, False, False, False, False])


if __name__ == "__main__":
    unittest.main()
