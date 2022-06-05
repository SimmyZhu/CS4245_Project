import os
from utils import *
from tensorflow import keras
from sklearn.model_selection import train_test_split

if __name__ == "__main__":
    list_size = 1024
    data_set = []
    label_set = []
    for folder_name in os.listdir('MATLAB/Point Cloud Dataset'):
        # print('Directory:', folder_name)
        for file_name in os.listdir('MATLAB/Point Cloud Dataset/' + folder_name):
            # print('File:', file_name)
            file = open('MATLAB/Point Cloud Dataset/' + folder_name + '/' + file_name)
            data_point = np.genfromtxt('MATLAB/Point Cloud Dataset/' + folder_name + '/' + file_name,
                                       delimiter=',').tolist()
            # Data Normalization
            data_point = np.array(data_point)
            data_point = np.ndarray.tolist(
                (data_point - np.mean(data_point, axis=0)) / (np.std(data_point, axis=0) + 1e-6))
            data_point += [[0, 0, 0, 0]] * (list_size - len(data_point))
            label_set.append(int(file_name[0]))
            data_set.append(data_point)
    label_set = np.expand_dims(np.array(label_set), -1)
    label_set = label_set - 1
    data_set = np.array(data_set)

# Model Parameters
NUM_POINTS = 1024
NUM_CLASSES = 6
BATCH_SIZE = 32

# Data Split for training and testing
train_points, test_points, train_labels, test_labels = train_test_split(data_set, label_set, test_size=0.20,
                                                                        random_state=42)

# Shuffle the data for training and testing
train_dataset = tf.data.Dataset.from_tensor_slices((train_points, train_labels))
test_dataset = tf.data.Dataset.from_tensor_slices((test_points, test_labels))
train_dataset = train_dataset.shuffle(len(train_points)).batch(BATCH_SIZE)
test_dataset = test_dataset.shuffle(len(test_points)).batch(BATCH_SIZE)

# Inputs
inputs = keras.Input(shape=(NUM_POINTS, 4))

# Main Network (T-net removed)
# x = tnet(inputs, 3)
x = conv_bn(inputs, 32)
x = conv_bn(x, 32)
# x = tnet(x, 32)
x = conv_bn(x, 32)
x = conv_bn(x, 64)
x = conv_bn(x, 512)
x = layers.GlobalMaxPooling1D()(x)
x = dense_bn(x, 256)
x = layers.Dropout(0.3)(x)
x = dense_bn(x, 128)
x = layers.Dropout(0.3)(x)

# Output
outputs = layers.Dense(NUM_CLASSES, activation="softmax")(x)

# Build the model
model = keras.Model(inputs=inputs, outputs=outputs, name="pointnet")

# Model Training
model.compile(
    loss="sparse_categorical_crossentropy",
    optimizer=keras.optimizers.Adam(learning_rate=0.001),
    metrics=["sparse_categorical_accuracy"],
)
model.fit(train_dataset, epochs=20, validation_data=test_dataset)

# Save the trained model
