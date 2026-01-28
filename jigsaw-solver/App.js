import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { ImageProvider } from './src/context/ImageContext';
import {
  HomeScreen,
  TargetImageScreen,
  CandidateImagesScreen,
  ResultsScreen,
} from './src/screens';

const Stack = createNativeStackNavigator();

const screenOptions = {
  headerStyle: {
    backgroundColor: '#fff',
  },
  headerTintColor: '#4285f4',
  headerTitleStyle: {
    fontWeight: '600',
  },
  headerShadowVisible: false,
  contentStyle: {
    backgroundColor: '#f5f7fa',
  },
};

export default function App() {
  return (
    <ImageProvider>
      <NavigationContainer>
        <Stack.Navigator screenOptions={screenOptions}>
          <Stack.Screen
            name="Home"
            component={HomeScreen}
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="TargetImage"
            component={TargetImageScreen}
            options={{ title: 'Target Image' }}
          />
          <Stack.Screen
            name="CandidateImages"
            component={CandidateImagesScreen}
            options={{ title: 'Candidate Pieces' }}
          />
          <Stack.Screen
            name="Results"
            component={ResultsScreen}
            options={{ title: 'Results', headerBackVisible: false }}
          />
        </Stack.Navigator>
        <StatusBar style="auto" />
      </NavigationContainer>
    </ImageProvider>
  );
}
