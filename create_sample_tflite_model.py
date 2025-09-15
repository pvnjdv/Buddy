#!/usr/bin/env python3
"""
Create a sample TensorFlow Lite model for testing purposes.
This creates a simple text classification model that can be used
to test the TFLite integration in the Buddy app.
"""

import tensorflow as tf
import numpy as np
import os

def create_simple_text_model():
    """Create a simple text classification model and convert to TFLite"""
    
    # Create a simple sequential model
    model = tf.keras.Sequential([
        tf.keras.layers.Embedding(input_dim=1000, output_dim=64, input_length=50),
        tf.keras.layers.LSTM(32),
        tf.keras.layers.Dense(16, activation='relu'),
        tf.keras.layers.Dense(8, activation='relu'),
        tf.keras.layers.Dense(1, activation='sigmoid')
    ])
    
    model.compile(
        optimizer='adam',
        loss='binary_crossentropy',
        metrics=['accuracy']
    )
    
    # Create some dummy training data
    X_train = np.random.randint(0, 1000, (100, 50))
    y_train = np.random.randint(0, 2, (100, 1))
    
    # Train the model briefly
    print("Training sample model...")
    model.fit(X_train, y_train, epochs=3, verbose=1)
    
    # Convert to TensorFlow Lite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Convert the model
    tflite_model = converter.convert()
    
    # Save the model
    output_path = '/home/pvn/Desktop/Buddy/sample_text_model.tflite'
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"✅ Sample TFLite model created: {output_path}")
    print(f"📦 Model size: {len(tflite_model) / 1024:.1f} KB")
    
    return output_path

def create_minimal_chatbot_model():
    """Create an even simpler model for chatbot testing"""
    
    # Very simple model that just processes text input
    model = tf.keras.Sequential([
        tf.keras.layers.Dense(64, activation='relu', input_shape=(100,)),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dense(16, activation='relu'),
        tf.keras.layers.Dense(5, activation='softmax')  # 5 response categories
    ])
    
    model.compile(
        optimizer='adam',
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # Dummy data
    X_train = np.random.random((50, 100))
    y_train = tf.keras.utils.to_categorical(np.random.randint(0, 5, 50), 5)
    
    print("Training minimal chatbot model...")
    model.fit(X_train, y_train, epochs=2, verbose=1)
    
    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    tflite_model = converter.convert()
    
    # Save the model
    output_path = '/home/pvn/Desktop/Buddy/buddy_chatbot.tflite'
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"✅ Minimal chatbot TFLite model created: {output_path}")
    print(f"📦 Model size: {len(tflite_model) / 1024:.1f} KB")
    
    return output_path

if __name__ == "__main__":
    print("🤖 Creating sample TensorFlow Lite models for Buddy AI...")
    
    try:
        # Create both models
        text_model = create_simple_text_model()
        chatbot_model = create_minimal_chatbot_model()
        
        print("\n🎉 Sample models created successfully!")
        print(f"📁 Text model: {text_model}")
        print(f"💬 Chatbot model: {chatbot_model}")
        print("\nYou can now test these models with your Buddy app's TensorFlow Lite integration.")
        
    except Exception as e:
        print(f"❌ Error creating models: {e}")
        print("Make sure you have TensorFlow installed: pip install tensorflow")
